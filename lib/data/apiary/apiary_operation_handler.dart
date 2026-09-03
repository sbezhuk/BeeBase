import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
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
final class ApiaryOperationHandler extends Repository
    implements OperationHandler {
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
      OperationType.imageAdd => _handleImageAdd(operation),
      OperationType.delete => Future.value(
        const OperationPermanentFailure('Offline delete is not supported yet.'),
      ),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final request = await _withResolvedAddress(
      ApiaryRequest.fromJson(operation.payload),
    );
    final result = await on(
      () => dataSource.createApiary(request, idempotencyKey: operation.id),
    );

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(
        operation,
        newEntityId: response.id,
        newType: OperationType.update,
      );
      if (retargeted != null) {
        await _reconcileCache(
          operation.localEntityId,
          response,
          latestPayload: retargeted.payload,
        );
        refreshNotifier.notify();
        return const OperationSuperseded();
      }
      await _reconcileCache(operation.localEntityId, response);
      await _markSynced(operation, resolvedEntityId: response.id);
      refreshNotifier.notify();
      return OperationSuccess(resolvedEntityId: response.id);
    });
  }

  Future<OperationResult> _handleUpdate(OfflineOperation operation) async {
    final id = operation.localEntityId;
    if (id == null) {
      return const OperationPermanentFailure('Missing target id for update.');
    }
    final request = await _withResolvedAddress(
      ApiaryRequest.fromJson(operation.payload),
    );
    final result = await on(() => dataSource.updateApiary(id, request));

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(
        operation,
        newEntityId: id,
        newType: OperationType.update,
      );
      if (retargeted != null) {
        await _reconcileCache(id, response, latestPayload: retargeted.payload);
        refreshNotifier.notify();
        return const OperationSuperseded();
      }
      await _reconcileCache(id, response);
      await _markSynced(operation);
      refreshNotifier.notify();
      return const OperationSuccess();
    });
  }

  /// Links one already-uploaded media id to this apiary, replaying
  /// `ApiaryRepositoryImpl.addApiaryImage`'s queued half. Requires both:
  ///  - the photo's own upload to have synced ([OfflineOperation.
  ///    dependsOnOperationId] always points at that `media` `create`
  ///    operation - see `MediaRepositoryImpl._attachOffline`), so there's a
  ///    real media id to send; and
  ///  - this apiary's own id to be real (see [_resolveRealSelfId]) - it may
  ///    itself still be local if the photo was picked before this apiary's
  ///    own `create` synced.
  /// Neither check is `SyncEngine`'s job: it only ever verifies the single
  /// `dependsOnOperationId` dependency (the upload), so the apiary's own
  /// readiness is re-checked here, mirroring `HiveOperationHandler.
  /// _resolveApiaryId`'s identical pattern for a hive depending on its
  /// apiary.
  Future<OperationResult> _handleImageAdd(OfflineOperation operation) async {
    final mediaId = await _resolveDependencyId(operation.dependsOnOperationId);
    if (mediaId == null) {
      return const OperationRetryableFailure(
        'The photo upload has not synced yet.',
      );
    }
    final apiaryId = await _resolveRealSelfId(operation.localEntityId);
    if (apiaryId == null) {
      return const OperationRetryableFailure('This apiary has not synced yet.');
    }

    final result = await on(() async {
      final current = await dataSource.getApiary(apiaryId);
      final request = ApiaryRequest(
        name: current.name,
        description: current.description,
        location: current.location,
        lat: current.lat,
        lon: current.lon,
        images: {...current.images, mediaId}.toList(),
      );
      return dataSource.updateApiary(apiaryId, request);
    });

    return result.fold(_classify, (response) async {
      await _reconcileCache(apiaryId, response);
      await _markSynced(operation, resolvedEntityId: mediaId);
      refreshNotifier.notify();
      return OperationSuccess(resolvedEntityId: mediaId);
    });
  }

  /// The real, server-assigned id for the entity identified by the local id
  /// [rawId] once its own `create` operation has synced - `null` while
  /// still pending/failed, or if [rawId] was never local to begin with (in
  /// which case it's returned unchanged). Same pattern as
  /// `HiveOperationHandler._resolveApiaryId`/`MediaOperationHandler.
  /// _resolveOwnerId`, specialized to an entity resolving *its own* id
  /// rather than a dependent's.
  Future<String?> _resolveRealSelfId(String? rawId) async {
    if (rawId == null) return null;
    if (!LocalIdGenerator.isLocal(rawId)) {
      return rawId;
    }
    final operations = await operationQueue.all();
    for (final op in operations) {
      if (op.entityType == 'apiary' &&
          op.localEntityId == rawId &&
          op.operationType == OperationType.create) {
        return op.status == OperationStatus.synced ? op.resolvedEntityId : null;
      }
    }
    return null;
  }

  Future<String?> _resolveDependencyId(String? dependsOnOperationId) async {
    if (dependsOnOperationId == null) return null;
    final dependency = await operationQueue.find(dependsOnOperationId);
    return dependency?.status == OperationStatus.synced
        ? dependency?.resolvedEntityId
        : null;
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

    final resolvedLocation = await locationService.resolveAddress(
      latitude: lat,
      longitude: lon,
    );
    return ApiaryRequest(
      name: request.name,
      description: request.description,
      location: resolvedLocation,
      lat: lat,
      lon: lon,
    );
  }

  /// Marks [operation] `synced` in the queue before [refreshNotifier] fires.
  /// [SyncEngine] makes this exact same write itself once `handle()`
  /// returns (see `SyncEngineImpl._process`), but only *after* the handler
  /// call completes — which is too late for a UI refresh triggered by the
  /// notify below: it would still find this operation `inProgress` in the
  /// queue and keep showing a "needs sync" badge for an apiary that has, in
  /// fact, already synced. `SyncEngineImpl`'s later write just repeats this
  /// (harmlessly) with a fresher `updatedAt` once it re-reads the row.
  Future<void> _markSynced(
    OfflineOperation operation, {
    String? resolvedEntityId,
  }) {
    return operationQueue.update(
      operation.copyWith(
        status: OperationStatus.synced,
        resolvedEntityId: resolvedEntityId,
        updatedAt: DateTime.now(),
      ),
    );
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
    final retargeted = current.copyWith(
      operationType: newType,
      localEntityId: newEntityId,
      status: OperationStatus.pending,
    );
    await operationQueue.update(retargeted);
    return retargeted;
  }

  /// Replaces the cache placeholder keyed by [localEntityId] with
  /// [serverResponse] — or, when [latestPayload] is given (the entity was
  /// edited again after this request was sent), with the newer field values
  /// under the server's id instead of the now-stale response fields.
  Future<void> _reconcileCache(
    String? localEntityId,
    ApiaryResponse serverResponse, {
    Map<String, dynamic>? latestPayload,
  }) {
    // images always comes from serverResponse, never from latestPayload: a
    // field-edit's own request payload never carries one (see
    // [ApiaryRequest.images]), so serverResponse.images - the apiary's
    // actual attached set as of the request that just completed - is the
    // best available answer, superseding retarget or not.
    final resolved = latestPayload == null
        ? serverResponse
        : ApiaryRequest.fromJson(latestPayload).toResponse(
            id: serverResponse.id,
            createdAt: serverResponse.createdAt,
            updatedAt: DateTime.now(),
            images: serverResponse.images,
          );
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where(
        (response) => response.id != localEntityId,
      );
      return [...withoutPlaceholder, resolved];
    });
  }
}
