import 'dart:async';

import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/core/services/connectivity_service.dart';

final class SyncEngineImpl implements SyncEngine {
  SyncEngineImpl({required this.queue, required this.registry, required this.connectivity});

  static const _maxRetries = 5;

  final OperationQueue queue;
  final OperationRegistry registry;
  final IConnectivityService connectivity;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _syncing = false;

  @override
  void start() {
    unawaited(syncNow());
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.status.listen((online) {
      if (online) {
        unawaited(syncNow());
      }
    });
  }

  /// Guarded by [_syncing] rather than relying solely on [OperationQueue]'s
  /// internal lock — that lock only protects a single read-modify-write, not
  /// the whole read-then-process-each-operation sequence below, so two
  /// overlapping calls (e.g. [start]'s initial attempt racing an immediate
  /// connectivity event) could otherwise both pick up and process the same
  /// pending operation.
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
      final pending = (await queue.all()).where((operation) => operation.status == OperationStatus.pending);
      for (final operation in pending) {
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

    switch (result) {
      case OperationSuccess():
        await queue.update(operation.copyWith(status: OperationStatus.synced, updatedAt: DateTime.now()));
      case OperationPermanentFailure(:final message):
        await queue.update(operation.copyWith(status: OperationStatus.failed, lastError: message, updatedAt: DateTime.now()));
      case OperationRetryableFailure(:final message):
        final nextRetryCount = operation.retryCount + 1;
        final nextStatus = nextRetryCount >= _maxRetries ? OperationStatus.failed : OperationStatus.pending;
        await queue.update(
          operation.copyWith(status: nextStatus, retryCount: nextRetryCount, lastError: message, updatedAt: DateTime.now()),
        );
    }
  }
}
