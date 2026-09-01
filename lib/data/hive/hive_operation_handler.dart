import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/extensions/hive_extension.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';

const _payloadApiaryIdKey = 'apiaryId';

/// Executes a queued Hive operation when the [SyncEngine] drains the queue.
/// Extends [Repository] purely to reuse its `on()` exception→Failure
/// classification — the same rule already governs online reads/writes, so
/// there is exactly one place that decides what counts as a permanent vs a
/// retryable failure.
final class HiveOperationHandler extends Repository implements OperationHandler {
  HiveOperationHandler({
    required this.dataSource,
    required this.localDataSource,
    required this.refreshNotifier,
    required this.operationQueue,
  });

  final IHiveDataSource dataSource;
  final LocalDataSource<List<HiveResponse>> localDataSource;
  final HiveListRefreshNotifier refreshNotifier;
  final OperationQueue operationQueue;

  @override
  String get entityType => 'hive';

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.create => _handleCreate(operation),
      OperationType.update => _handleUpdate(operation),
      OperationType.delete => Future.value(const OperationPermanentFailure('Offline delete is not supported yet.')),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final rawApiaryId = operation.payload[_payloadApiaryIdKey] as String;
    final apiaryId = await _resolveApiaryId(rawApiaryId, operation.dependsOnOperationId);
    if (apiaryId == null) {
      return const OperationRetryableFailure('The parent apiary has not synced yet.');
    }
    final request = HiveRequest.fromJson(operation.payload);
    final result = await on(() => dataSource.createHive(request, apiaryId: apiaryId, idempotencyKey: operation.id));

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(operation, newEntityId: response.id, newType: OperationType.update);
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

  /// Resolves the apiary id to actually send with a queued create. Most of
  /// the time [rawApiaryId] (the id captured when the hive was created
  /// offline) is already a real backend id and is returned as-is. When the
  /// hive was created under an apiary that was *itself* still a local
  /// placeholder, [rawApiaryId] is a local id the backend has never heard
  /// of — the real id has to be read off the apiary's own now-synced
  /// operation (see [OfflineOperation.dependsOnOperationId] /
  /// [OfflineOperation.resolvedEntityId]). Returns `null` if that dependency
  /// hasn't synced yet, which `SyncEngine` should already have prevented by
  /// not dispatching this operation in the first place — this is a
  /// defensive fallback, not the primary guard.
  Future<String?> _resolveApiaryId(String rawApiaryId, String? dependsOnOperationId) async {
    if (!LocalIdGenerator.isLocal(rawApiaryId)) {
      return rawApiaryId;
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
    final request = HiveRequest.fromJson(operation.payload);
    final result = await on(() => dataSource.updateHive(id, request));

    return result.fold(_classify, (response) async {
      final retargeted = await _checkSupersededAndRetarget(operation, newEntityId: id, newType: OperationType.update);
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
  /// returns (see `SyncEngineImpl._process`), but only *after* the handler
  /// call completes — which is too late for a UI refresh triggered by the
  /// notify below: it would still find this operation `inProgress` in the
  /// queue and keep showing a "needs sync" badge for a hive that has, in
  /// fact, already synced (see the identical fix in
  /// `ApiaryOperationHandler._markSynced`). `SyncEngineImpl`'s later write
  /// just repeats this (harmlessly) with a fresher `updatedAt` once it
  /// re-reads the row.
  Future<void> _markSynced(OfflineOperation operation, {String? resolvedEntityId}) {
    return operationQueue.update(
      operation.copyWith(status: OperationStatus.synced, resolvedEntityId: resolvedEntityId, updatedAt: DateTime.now()),
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
    final retargeted = current.copyWith(operationType: newType, localEntityId: newEntityId, status: OperationStatus.pending);
    await operationQueue.update(retargeted);
    return retargeted;
  }

  /// Replaces the cache placeholder keyed by [localEntityId] with
  /// [serverResponse] — or, when [latestPayload] is given (the entity was
  /// edited again after this request was sent), with the newer field values
  /// under the server's id instead of the now-stale response fields.
  Future<void> _reconcileCache(String? localEntityId, HiveResponse serverResponse, {Map<String, dynamic>? latestPayload}) {
    final resolved = latestPayload == null
        ? serverResponse
        : HiveRequest.fromJson(latestPayload).toResponse(
            id: serverResponse.id,
            apiaryId: latestPayload[_payloadApiaryIdKey] as String,
            createdAt: serverResponse.createdAt,
            updatedAt: DateTime.now(),
          );
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where((response) => response.id != localEntityId);
      return [...withoutPlaceholder, resolved];
    });
  }
}
