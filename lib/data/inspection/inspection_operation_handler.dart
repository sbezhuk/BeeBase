import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/extensions/inspection_extension.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';

const _payloadHiveIdKey = 'hiveId';

/// Executes a queued Inspection operation when the [SyncEngine] drains the
/// queue. Extends [Repository] purely to reuse its `on()` exception→Failure
/// classification — the same rule already governs online reads/writes, so
/// there is exactly one place that decides what counts as a permanent vs a
/// retryable failure. Mirrors [HiveOperationHandler].
final class InspectionOperationHandler extends Repository implements OperationHandler {
  InspectionOperationHandler({
    required this.dataSource,
    required this.localDataSource,
    required this.refreshNotifier,
    required this.operationQueue,
  });

  final IInspectionDataSource dataSource;
  final LocalDataSource<List<InspectionResponse>> localDataSource;
  final InspectionListRefreshNotifier refreshNotifier;
  final OperationQueue operationQueue;

  @override
  String get entityType => 'inspection';

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.create => _handleCreate(operation),
      OperationType.update => _handleUpdate(operation),
      OperationType.delete => Future.value(
        const OperationPermanentFailure('Offline delete is not supported yet.'),
      ),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final rawHiveId = operation.payload[_payloadHiveIdKey] as String;
    final hiveId = await _resolveHiveId(rawHiveId, operation.dependsOnOperationId);
    if (hiveId == null) {
      return const OperationRetryableFailure('The parent hive has not synced yet.');
    }
    final request = InspectionRequest.fromJson(operation.payload);
    final result = await on(
      () => dataSource.createInspection(hiveId, request, idempotencyKey: operation.id),
    );

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(
        operation,
        newEntityId: response.id,
        newType: OperationType.update,
      );
      if (retargeted != null) {
        await _reconcileCache(operation.localEntityId, response, latestPayload: retargeted.payload);
        refreshNotifier.notify();
        return const OperationSuperseded();
      }
      await _reconcileCache(operation.localEntityId, response);
      await _markSynced(operation, resolvedEntityId: response.id);
      refreshNotifier.notify();
      return OperationSuccess(resolvedEntityId: response.id);
    });
  }

  /// Resolves the hive id to actually send with a queued create. Most of the
  /// time [rawHiveId] (the id captured when the inspection was created
  /// offline) is already a real backend id and is returned as-is. When the
  /// inspection was created under a hive that was *itself* still a local
  /// placeholder, [rawHiveId] is a local id the backend has never heard of —
  /// the real id has to be read off the hive's own now-synced operation (see
  /// [OfflineOperation.dependsOnOperationId] / [OfflineOperation.resolvedEntityId]).
  /// Returns `null` if that dependency hasn't synced yet, which `SyncEngine`
  /// should already have prevented by not dispatching this operation in the
  /// first place — this is a defensive fallback, not the primary guard.
  Future<String?> _resolveHiveId(String rawHiveId, String? dependsOnOperationId) async {
    if (!LocalIdGenerator.isLocal(rawHiveId)) {
      return rawHiveId;
    }
    if (dependsOnOperationId == null) {
      return null;
    }
    final dependency = await operationQueue.find(dependsOnOperationId);
    return dependency?.resolvedEntityId;
  }

  Future<OperationResult> _handleUpdate(OfflineOperation operation) async {
    final id = operation.localEntityId;
    if (id == null) {
      return const OperationPermanentFailure('Missing target id for update.');
    }
    final rawHiveId = operation.payload[_payloadHiveIdKey] as String;
    final hiveId = await _resolveHiveId(rawHiveId, operation.dependsOnOperationId);
    if (hiveId == null) {
      return const OperationRetryableFailure('The parent hive has not synced yet.');
    }
    final request = InspectionRequest.fromJson(operation.payload);
    final result = await on(() => dataSource.updateInspection(hiveId, id, request));

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

  /// Marks [operation] `synced` in the queue before [refreshNotifier] fires.
  /// [SyncEngine] makes this exact same write itself once `handle()`
  /// returns, but only *after* the handler call completes — which is too
  /// late for a UI refresh triggered by the notify below (see the identical
  /// fix in `HiveOperationHandler._markSynced`).
  Future<void> _markSynced(OfflineOperation operation, {String? resolvedEntityId}) {
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
    InspectionResponse serverResponse, {
    Map<String, dynamic>? latestPayload,
  }) {
    final resolved = latestPayload == null
        ? serverResponse
        : InspectionRequest.fromJson(latestPayload).toResponse(
            id: serverResponse.id,
            hiveId: latestPayload[_payloadHiveIdKey] as String,
            createdAt: serverResponse.createdAt,
            updatedAt: DateTime.now(),
          );
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where(
        (response) => response.id != localEntityId,
      );
      return [...withoutPlaceholder, resolved];
    });
  }
}
