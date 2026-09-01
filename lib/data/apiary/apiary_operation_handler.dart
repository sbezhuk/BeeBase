import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';

/// Executes a queued Apiary operation when the [SyncEngine] drains the
/// queue. Extends [Repository] purely to reuse its `on()` exception→Failure
/// classification — the same rule already governs online reads/writes, so
/// there is exactly one place that decides what counts as a permanent vs a
/// retryable failure.
final class ApiaryOperationHandler extends Repository implements OperationHandler {
  ApiaryOperationHandler({
    required this.dataSource,
    required this.localDataSource,
    required this.refreshNotifier,
    required this.operationQueue,
    required this.locationService,
  });

  final IApiaryDataSource dataSource;
  final LocalDataSource<List<ApiaryResponse>> localDataSource;
  final ApiaryListRefreshNotifier refreshNotifier;
  final OperationQueue operationQueue;
  final LocationService locationService;

  @override
  String get entityType => 'apiary';

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.create => _handleCreate(operation),
      OperationType.update => _handleUpdate(operation),
      OperationType.delete => Future.value(const OperationPermanentFailure('Offline delete is not supported yet.')),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final request = await _withResolvedAddress(ApiaryRequest.fromJson(operation.payload));
    final result = await on(() => dataSource.createApiary(request, idempotencyKey: operation.id));

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(operation, newEntityId: response.id, newType: OperationType.update);
      if (retargeted != null) {
        await _reconcileCache(operation.localEntityId, response, latestPayload: retargeted.payload);
        refreshNotifier.notify();
        return const OperationSuperseded();
      }
      await _reconcileCache(operation.localEntityId, response);
      refreshNotifier.notify();
      return OperationSuccess(resolvedEntityId: response.id);
    });
  }

  Future<OperationResult> _handleUpdate(OfflineOperation operation) async {
    final id = operation.localEntityId;
    if (id == null) {
      return const OperationPermanentFailure('Missing target id for update.');
    }
    final request = await _withResolvedAddress(ApiaryRequest.fromJson(operation.payload));
    final result = await on(() => dataSource.updateApiary(id, request));

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(operation, newEntityId: id, newType: OperationType.update);
      if (retargeted != null) {
        await _reconcileCache(id, response, latestPayload: retargeted.payload);
        refreshNotifier.notify();
        return const OperationSuperseded();
      }
      await _reconcileCache(id, response);
      refreshNotifier.notify();
      return const OperationSuccess();
    });
  }

  /// Re-resolves [request]'s address from its coordinates before it's sent.
  /// An apiary created/updated offline has its `location` set to the
  /// offline placeholder (or, if geocoding failed while online, raw
  /// coordinates) — by the time this handler runs, the [SyncEngine] has
  /// connectivity, so this is the point where that placeholder gets
  /// replaced with the real street/city name. Left untouched when there are
  /// no coordinates to resolve from.
  Future<ApiaryRequest> _withResolvedAddress(ApiaryRequest request) async {
    final lat = request.lat;
    final lon = request.lon;
    if (lat == null || lon == null) return request;

    final resolvedLocation = await locationService.resolveAddress(latitude: lat, longitude: lon);
    return ApiaryRequest(name: request.name, description: request.description, location: resolvedLocation, lat: lat, lon: lon);
  }

  Future<OperationResult> _classify(Failure failure) async {
    return failure is ServerFailure
        ? OperationPermanentFailure(failure.message.resolve())
        : OperationRetryableFailure(failure.message.resolve());
  }

  /// If a newer local edit was consolidated into [sent]'s row after it was
  /// read for sending (its `version` moved on), the response just received
  /// no longer reflects the entity's current desired state. Re-targets the
  /// row at [newEntityId] as an [newType] operation carrying that newer
  /// payload, left `pending` for another sync pass, and returns it — `null`
  /// when nothing raced it, meaning the caller can treat this as a plain
  /// success.
  Future<OfflineOperation?> _checkSupersededAndRetarget(
    OfflineOperation sent, {
    required String newEntityId,
    required OperationType newType,
  }) async {
    final current = await operationQueue.find(sent.id);
    if (current == null || current.version == sent.version) {
      return null;
    }
    final retargeted = current.copyWith(operationType: newType, localEntityId: newEntityId, status: OperationStatus.pending);
    await operationQueue.update(retargeted);
    return retargeted;
  }

  /// Replaces the cache placeholder keyed by [localEntityId] with
  /// [serverResponse] — or, when [latestPayload] is given (the entity was
  /// edited again after this request was sent), with the newer field values
  /// under the server's id instead of the now-stale response fields.
  Future<void> _reconcileCache(String? localEntityId, ApiaryResponse serverResponse, {Map<String, dynamic>? latestPayload}) {
    final resolved = latestPayload == null
        ? serverResponse
        : ApiaryRequest.fromJson(
            latestPayload,
          ).toResponse(id: serverResponse.id, createdAt: serverResponse.createdAt, updatedAt: DateTime.now());
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where((response) => response.id != localEntityId);
      return [...withoutPlaceholder, resolved];
    });
  }
}
