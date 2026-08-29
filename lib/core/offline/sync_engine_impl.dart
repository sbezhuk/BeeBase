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
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<void>? _queueSubscription;
  bool _syncing = false;

  @override
  ValueListenable<bool> get syncAvailable => _syncAvailable;

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
    final hasUnsynced = online && (await queue.all()).any(_needsSync);
    _syncAvailable.value = hasUnsynced;
  }

  bool _needsSync(OfflineOperation operation) =>
      operation.status == OperationStatus.pending || operation.status == OperationStatus.failed;

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
    final handler = registry.handlerFor(operation.entityType);
    if (handler == null) {
      return;
    }

    await queue.update(operation.copyWith(status: OperationStatus.inProgress, updatedAt: DateTime.now()));
    final result = await handler.handle(operation);

    // Re-read the row rather than trusting the pre-call `operation`: a
    // handler may have consolidated a newer local edit into it (or, on
    // supersession, rewritten it entirely) while the request was in flight.
    // Basing the final write on the current row means that edit's payload
    // is never clobbered back to what was actually sent.
    final current = await queue.find(operation.id) ?? operation;

    switch (result) {
      case OperationSuccess():
        await queue.update(current.copyWith(status: OperationStatus.synced, updatedAt: DateTime.now()));
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
