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
  SyncEngineImpl({
    required this.queue,
    required this.registry,
    required this.connectivity,
    this.retryDelay = const Duration(seconds: 2),
  });

  final OperationQueue queue;
  final OperationRegistry registry;
  final IConnectivityService connectivity;

  /// Delay between in-pass retry attempts in [syncNow] — overridable so
  /// tests don't need to wait on the real clock.
  final Duration retryDelay;

  final ValueNotifier<bool> _syncAvailable = ValueNotifier(false);
  final ValueNotifier<bool> _hasPendingOperations = ValueNotifier(false);
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<void>? _queueSubscription;
  bool _syncing = false;
  // Starts `false` rather than `null` on purpose: a cold start that's
  // already online with operations left pending from a previous offline
  // session (app was killed/crashed before it could sync) must also count
  // as "just reconnected" and trigger an automatic sync, not just a live
  // offline→online transition.
  bool _wasOnline = false;

  @override
  ValueListenable<bool> get syncAvailable => _syncAvailable;

  @override
  ValueListenable<bool> get hasPendingOperations => _hasPendingOperations;

  @override
  void start() {
    unawaited(refreshAvailability());
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.status.listen(
      (_) => refreshAvailability(),
    );
    _queueSubscription?.cancel();
    _queueSubscription = queue.changes.listen((_) => refreshAvailability());
  }

  @override
  Future<void> refreshAvailability() async {
    final online = await connectivity.isOnline;
    final all = await queue.all();
    final pending = all.where(_needsSync).toList();
    final hasUnsynced = pending.isNotEmpty;
    _hasPendingOperations.value = hasUnsynced;
    _syncAvailable.value = online && hasUnsynced;

    final justReconnected = online && !_wasOnline;
    _wasOnline = online;

    if (justReconnected) {
      debugPrint('[SyncEngine] Connectivity restored.');
      if (hasUnsynced) {
        debugPrint(
          '[SyncEngine] ${pending.length} pending operation(s) found on reconnect — starting automatic sync.',
        );
        await syncNow();
      }
    }
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

  // How many times a single `syncNow()` call will re-attempt an operation
  // that keeps ending this same call still `failed`, before leaving it for
  // the next external trigger (another connectivity event, app resume, or a
  // manual "Sync now"). Covers a transient hiccup right at the reconnect
  // moment (the OS reports link-layer connectivity a moment before the
  // network is actually routable, a decode error from a response that
  // arrives incomplete under a flaky first request, ...) without making the
  // user wait for a second connectivity flip — or restart the app — to see
  // data that, from the backend's perspective, may already be synced.
  static const _maxAttemptsPerOperation = 3;

  @override
  Future<void> syncNow() async {
    if (_syncing) {
      debugPrint(
        '[SyncEngine] syncNow() called while a sync is already in progress — skipping.',
      );
      return;
    }
    if (!await connectivity.isOnline) {
      debugPrint('[SyncEngine] syncNow() called while offline — skipping.');
      return;
    }
    _syncing = true;
    try {
      var toProcess = (await queue.all()).where(_needsSync).toList();
      var attempt = 1;
      while (toProcess.isNotEmpty) {
        debugPrint(
          '[SyncEngine] Sync attempt #$attempt started — ${toProcess.length} operation(s) to process.',
        );
        final attemptedIds = toProcess.map((operation) => operation.id).toSet();
        for (final operation in toProcess) {
          await _process(operation);
        }
        debugPrint('[SyncEngine] Sync attempt #$attempt finished.');

        if (attempt >= _maxAttemptsPerOperation) {
          break;
        }
        if (!await connectivity.isOnline) {
          debugPrint(
            '[SyncEngine] Lost connectivity mid-sync — leaving anything still unsynced for the next reconnect.',
          );
          break;
        }
        final stillFailing = <OfflineOperation>[];
        for (final id in attemptedIds) {
          final row = await queue.find(id);
          if (row != null && row.status == OperationStatus.failed) {
            stillFailing.add(row);
          }
        }
        if (stillFailing.isEmpty) {
          break;
        }
        attempt++;
        debugPrint(
          '[SyncEngine] ${stillFailing.length} operation(s) still failing after this attempt — '
          'retrying in ${retryDelay.inSeconds}s (attempt #$attempt of $_maxAttemptsPerOperation).',
        );
        await Future<void>.delayed(retryDelay);
        toProcess = stillFailing;
      }
      debugPrint('[SyncEngine] Sync finished.');
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
        debugPrint(
          '[SyncEngine] ${_label(operation)} waiting on dependency $dependsOnId (not yet synced) — deferring to next sync.',
        );
        return;
      }
    }

    final handler = registry.handlerFor(operation.entityType);
    if (handler == null) {
      debugPrint(
        '[SyncEngine] ${_label(operation)} has no registered handler for "${operation.entityType}" — skipping.',
      );
      return;
    }

    debugPrint(
      '[SyncEngine] ${_label(operation)} attempt #${operation.retryCount + 1} starting.',
    );
    await queue.update(
      operation.copyWith(
        status: OperationStatus.inProgress,
        updatedAt: DateTime.now(),
      ),
    );

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
      debugPrint('[SyncEngine] ${_label(operation)} threw during handling: $e');
      final current = await queue.find(operation.id) ?? operation;
      // A handler marks its row `synced` itself, as the last step before
      // returning (see e.g. `ApiaryOperationHandler._markSynced`) — before
      // any post-success bookkeeping that isn't essential to the sync
      // itself (a refresh-notifier broadcast, a redundant cache touch). If
      // one of those non-essential steps is what actually threw, the
      // backend write and the durable `synced` row both already happened;
      // downgrading back to `failed` here would misreport a sync that
      // genuinely succeeded as broken, and queue it for a needless retry
      // (which, for a `create`, would resend under the same idempotency key
      // — harmless, but pointless). Re-reading `current` fresh (rather than
      // trusting the pre-call `operation`) is what makes this check see the
      // handler's own write.
      if (current.status == OperationStatus.synced) {
        debugPrint(
          '[SyncEngine] ${_label(operation)} was already marked synced before this exception — '
          'leaving it synced instead of overwriting it back to failed.',
        );
        return;
      }
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

    try {
      switch (result) {
        case OperationSuccess(:final resolvedEntityId):
          debugPrint(
            '[SyncEngine] ${_label(operation)} synced successfully'
            '${resolvedEntityId != null ? ' (resolved id: $resolvedEntityId)' : ''}.',
          );
          await queue.update(
            current.copyWith(
              status: OperationStatus.synced,
              resolvedEntityId: resolvedEntityId,
              updatedAt: DateTime.now(),
            ),
          );
        case OperationSuperseded():
          debugPrint(
            '[SyncEngine] ${_label(operation)} superseded by a newer local edit — left for the handler\'s own state.',
          );
        case OperationRetryableFailure(:final message) ||
            OperationPermanentFailure(:final message):
          debugPrint('[SyncEngine] ${_label(operation)} failed: $message');
          await queue.update(
            current.copyWith(
              status: OperationStatus.failed,
              retryCount: current.retryCount + 1,
              lastError: message,
              updatedAt: DateTime.now(),
            ),
          );
      }
    } catch (e) {
      // This write is bookkeeping on top of a result the handler already
      // determined (and, for `OperationSuccess`, already durably recorded
      // itself — see the comment above). Letting a failure here escape
      // uncaught would abort the rest of this `syncNow()` pass (every
      // operation after this one in `toProcess` silently skipped) over a
      // write that, for the success case, only repeats what already
      // happened. Logging and moving on keeps one bookkeeping hiccup from
      // taking the whole batch down with it, matching the handler-exception
      // guard above.
      debugPrint(
        '[SyncEngine] ${_label(operation)} result recorded ($result) but the queue bookkeeping write threw: $e',
      );
    }
  }

  String _label(OfflineOperation operation) =>
      '${operation.entityType}/${operation.operationType} (id=${operation.id})';
}
