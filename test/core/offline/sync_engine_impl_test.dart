import 'dart:async';

import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/offline/sync_engine_impl.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOperationHandler extends Mock implements OperationHandler {}

class MockConnectivityService extends Mock implements IConnectivityService {}

OfflineOperation _pendingOp({String id = 'op-1', int retryCount = 0, OperationStatus status = OperationStatus.pending}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'Test'},
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    retryCount: retryCount,
    localEntityId: 'local-1',
  );
}

void main() {
  late MockOperationQueue queue;
  late MockOperationHandler handler;
  late MockConnectivityService connectivity;
  late OperationRegistry registry;
  late SyncEngineImpl engine;

  setUpAll(() {
    registerFallbackValue(_pendingOp());
  });

  setUp(() {
    queue = MockOperationQueue();
    handler = MockOperationHandler();
    connectivity = MockConnectivityService();
    when(() => handler.entityType).thenReturn('apiary');
    registry = OperationRegistry({'apiary': handler});
    engine = SyncEngineImpl(queue: queue, registry: registry, connectivity: connectivity);
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => connectivity.status).thenAnswer((_) => const Stream.empty());
    when(() => queue.changes).thenAnswer((_) => const Stream.empty());
    when(() => queue.all()).thenAnswer((_) async => []);
    when(() => queue.update(any())).thenAnswer((_) async {});
    when(() => queue.find(any())).thenAnswer((_) async => null);
  });

  group('syncNow', () {
    test('does nothing when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      await engine.syncNow();

      verifyNever(() => queue.all());
    });

    test('marks a successful operation synced', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
      when(() => handler.handle(any())).thenAnswer((_) async => const OperationSuccess());

      await engine.syncNow();

      final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
      expect(updates.map((op) => op.status), [OperationStatus.inProgress, OperationStatus.synced]);
    });

    test('marks a retryable failure failed and bumps retryCount (no auto-retry loop exists anymore)', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
      when(() => handler.handle(any())).thenAnswer((_) async => const OperationRetryableFailure('timeout'));

      await engine.syncNow();

      final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
      final finalUpdate = updates.last;
      expect(finalUpdate.status, OperationStatus.failed);
      expect(finalUpdate.retryCount, 1);
      expect(finalUpdate.lastError, 'timeout');
    });

    test('marks a permanent failure failed and still bumps retryCount for observability', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
      when(() => handler.handle(any())).thenAnswer((_) async => const OperationPermanentFailure('validation failed'));

      await engine.syncNow();

      final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
      expect(updates.last.status, OperationStatus.failed);
      expect(updates.last.retryCount, 1);
      expect(updates.last.lastError, 'validation failed');
    });

    test('re-processes an already-failed operation — every sync is user-initiated now, no retry cap', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp(retryCount: 9, status: OperationStatus.failed)]);
      when(() => handler.handle(any())).thenAnswer((_) async => const OperationSuccess());

      await engine.syncNow();

      final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
      expect(updates.last.status, OperationStatus.synced);
    });

    test('skips an operation whose entity type has no registered handler', () async {
      final orphanOp = OfflineOperation(
        id: 'op-2',
        entityType: 'hive',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => queue.all()).thenAnswer((_) async => [orphanOp]);

      await engine.syncNow();

      verifyNever(() => queue.update(any()));
      verifyNever(() => handler.handle(any()));
    });

    test('ignores a synced operation', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp(status: OperationStatus.synced)]);

      await engine.syncNow();

      verifyNever(() => handler.handle(any()));
    });

    test('a plain success result is a no-op on the queue for OperationSuperseded', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
      when(() => handler.handle(any())).thenAnswer((_) async => const OperationSuperseded());

      await engine.syncNow();

      final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
      // Only the initial inProgress mark — the handler already left the row
      // in the state it wants (re-targeted and pending), so the engine must
      // not additionally mark it synced.
      expect(updates.map((op) => op.status), [OperationStatus.inProgress]);
    });

    test('a failure does not clobber a payload that changed while the request was in flight', () async {
      final sent = _pendingOp(id: 'op-1');
      when(() => queue.all()).thenAnswer((_) async => [sent]);
      final mutatedMidFlight = sent.copyWith(payload: const {'name': 'Edited While In Flight'}, version: 1);
      when(() => queue.find('op-1')).thenAnswer((_) async => mutatedMidFlight);
      when(() => handler.handle(any())).thenAnswer((_) async => const OperationRetryableFailure('timeout'));

      await engine.syncNow();

      final finalUpdate = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>().last;
      expect(finalUpdate.status, OperationStatus.failed);
      expect(finalUpdate.payload, {'name': 'Edited While In Flight'});
      expect(finalUpdate.version, 1);
    });
  });

  group('syncAvailable / start / refreshAvailability', () {
    test('is false before start() and while offline', () async {
      expect(engine.syncAvailable.value, isFalse);
    });

    test('refreshAvailability sets true when online with a pending operation', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);

      await engine.refreshAvailability();

      expect(engine.syncAvailable.value, isTrue);
    });

    test('refreshAvailability is false when offline even with pending operations', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);

      await engine.refreshAvailability();

      expect(engine.syncAvailable.value, isFalse);
    });

    test('refreshAvailability is false when online with nothing pending or failed', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp(status: OperationStatus.synced)]);

      await engine.refreshAvailability();

      expect(engine.syncAvailable.value, isFalse);
    });

    test('a failed operation also counts as available (so the user can retry it)', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp(status: OperationStatus.failed)]);

      await engine.refreshAvailability();

      expect(engine.syncAvailable.value, isTrue);
    });

    test('start() does NOT call syncNow when connectivity is restored — only refreshes availability', () async {
      final statusController = StreamController<bool>();
      when(() => connectivity.status).thenAnswer((_) => statusController.stream);
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);

      engine.start();
      await Future<void>.delayed(Duration.zero);

      statusController.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(engine.syncAvailable.value, isTrue);
      verifyNever(() => handler.handle(any()));
      verifyNever(() => queue.update(any()));

      await statusController.close();
    });

    test('start() reacts to the queue changing (a new operation enqueued while already online)', () async {
      final changesController = StreamController<void>();
      when(() => queue.changes).thenAnswer((_) => changesController.stream);
      when(() => queue.all()).thenAnswer((_) async => []);

      engine.start();
      await Future<void>.delayed(Duration.zero);
      expect(engine.syncAvailable.value, isFalse);

      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
      changesController.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(engine.syncAvailable.value, isTrue);

      await changesController.close();
    });
  });
}
