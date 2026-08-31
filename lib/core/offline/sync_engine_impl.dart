import 'dart:async';

import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:flutter/foundation.dart';

final class SyncEngineImpl implements SyncEngine {
  SyncEngineImpl({required this.queue, required this.registry, required this.connectivity});

  final OperationQueue queue;
  final OperationRegistry registry;
  final IConnectivityService connectivity;

  final ValueNotifier<bool> _syncAvailable = ValueNotifier(false);
  final ValueNotifier<bool> _hasPendingOperations = ValueNotifier(false);
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<void>? _queueSubscription;
  bool _syncing = false;

  @override
  ValueListenable<bool> get syncAvailable => _syncAvailable;

  @override
  ValueListenable<bool> get hasPendingOperations => _hasPendingOperations;

  @override
  void start() {
    unawaited(refreshAvailability());
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.status.listen((_) => refreshAvailability());
    _queueSubscription?.cancel();
    _queueSubscription = queue.changes.listen((_) => refreshAvailability());
  }

  @override
  Future<void> refreshAvailability() async {
    final online = await connectivity.isOnline;
    final hasUnsynced = (await queue.all()).any(_needsSync);
    _hasPendingOperations.value = hasUnsynced;
    _syncAvailable.value = online && hasUnsynced;
  }

  // `inProgress` is included so a row stranded there (a handler threw before
  // `_process` could resolve it to `synced`/`failed` — see the try/catch
  // below, which now prevents that for anything processed after this fix,
  // but a row already stuck on a device from before it shipped needs a way
  // back in) gets picked up by the next `syncNow()` instead of being
  // silently excluded forever.
  bool _needsSync(OfflineOperation operation) =>
      operation.status == OperationStatus.pending ||
      operation.status == OperationStatus.failed ||
      operation.status == OperationStatus.inProgress;

  @override
  Future<void> syncNow() async {
    if (_syncing) {
      return;
    }
    if (!await connectivity.isOnline) {
      return;
    }
    _syncing = true;
    try {
      final toProcess = (await queue.all()).where(_needsSync);
      for (final operation in toProcess) {
        await _process(operation);
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _process(OfflineOperation operation) async {
    // An operation that depends on another (e.g. creating a Hive under an
    // Apiary that was itself created offline) must not be sent until that
    // dependency has actually synced — its payload may still be pointing at
    // a local id the backend has never heard of. `queue.find` re-reads the
    // row fresh, so a dependency processed earlier in this same drain of the
    // queue (chronological order — see `SqliteOperationQueue.all`) is
    // already visible here without waiting for another `syncNow()` call.
    final dependsOnId = operation.dependsOnOperationId;
    if (dependsOnId != null) {
      final dependency = await queue.find(dependsOnId);
      if (dependency == null || dependency.status != OperationStatus.synced) {
        return;
      }
    }

    final handler = registry.handlerFor(operation.entityType);
    if (handler == null) {
      return;
    }

    await queue.update(operation.copyWith(status: OperationStatus.inProgress, updatedAt: DateTime.now()));

    final OperationResult result;
    try {
      result = await handler.handle(operation);
    } catch (e) {
      // A handler is expected to report failure through `OperationResult`,
      // not by throwing — `MediaOperationHandler` in particular calls into
      // local file I/O (`dio.MultipartFile.fromFile`, `DioMediaType.parse`)
      // that can throw something outside the `ServerException` /
      // `CancellationException` / `InternalException` set `Repository.on()`
      // catches. Left uncaught, that exception would abort this whole
      // `syncNow()` pass (every later operation in `toProcess` silently
      // skipped) and strand this row at `inProgress` forever, since
      // `_needsSync` — before this catch existed — never re-selected it.
      // Catching here keeps one bad operation from taking the rest of the
      // batch down with it and always resolves the row to `failed` so it's
      // retried on the next sync instead of disappearing.
      final current = await queue.find(operation.id) ?? operation;
      await queue.update(
        current.copyWith(
          status: OperationStatus.failed,
          retryCount: current.retryCount + 1,
          lastError: e.toString(),
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    // Re-read the row rather than trusting the pre-call `operation`: a
    // handler may have consolidated a newer local edit into it (or, on
    // supersession, rewritten it entirely) while the request was in flight.
    // Basing the final write on the current row means that edit's payload
    // is never clobbered back to what was actually sent.
    final current = await queue.find(operation.id) ?? operation;

    switch (result) {
      case OperationSuccess(:final resolvedEntityId):
        await queue.update(
          current.copyWith(status: OperationStatus.synced, resolvedEntityId: resolvedEntityId, updatedAt: DateTime.now()),
        );
      case OperationSuperseded():
        break;
      case OperationRetryableFailure(:final message) || OperationPermanentFailure(:final message):
        await queue.update(
          current.copyWith(
            status: OperationStatus.failed,
            retryCount: current.retryCount + 1,
            lastError: message,
            updatedAt: DateTime.now(),
          ),
        );
    }
  }
}
