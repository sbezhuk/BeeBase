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

OfflineOperation _pendingOp({String id = 'op-1', int retryCount = 0}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'Test'},
    status: OperationStatus.pending,
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
    when(() => queue.update(any())).thenAnswer((_) async {});
  });

  test('syncNow does nothing when offline', () async {
    when(() => connectivity.isOnline).thenAnswer((_) async => false);

    await engine.syncNow();

    verifyNever(() => queue.all());
  });

  test('syncNow marks a successful operation synced', () async {
    when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
    when(() => handler.handle(any())).thenAnswer((_) async => const OperationSuccess());

    await engine.syncNow();

    final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
    expect(updates.map((op) => op.status), [OperationStatus.inProgress, OperationStatus.synced]);
  });

  test('syncNow leaves a retryable failure pending and bumps retryCount', () async {
    when(() => queue.all()).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
    when(() => handler.handle(any())).thenAnswer((_) async => const OperationRetryableFailure('timeout'));

    await engine.syncNow();

    final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
    final finalUpdate = updates.last;
    expect(finalUpdate.status, OperationStatus.pending);
    expect(finalUpdate.retryCount, 1);
    expect(finalUpdate.lastError, 'timeout');
  });

  test('syncNow marks failed once the retry cap is reached', () async {
    when(() => queue.all()).thenAnswer((_) async => [_pendingOp(retryCount: 4)]);
    when(() => handler.handle(any())).thenAnswer((_) async => const OperationRetryableFailure('still failing'));

    await engine.syncNow();

    final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
    expect(updates.last.status, OperationStatus.failed);
  });

  test('syncNow marks a permanent failure failed immediately without bumping retryCount', () async {
    when(() => queue.all()).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
    when(() => handler.handle(any())).thenAnswer((_) async => const OperationPermanentFailure('validation failed'));

    await engine.syncNow();

    final updates = verify(() => queue.update(captureAny())).captured.cast<OfflineOperation>();
    expect(updates.last.status, OperationStatus.failed);
    expect(updates.last.retryCount, 0);
  });

  test('syncNow skips an operation whose entity type has no registered handler', () async {
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

  test('start triggers an initial sync and resyncs when connectivity is restored', () async {
    final statusController = StreamController<bool>();
    when(() => connectivity.status).thenAnswer((_) => statusController.stream);
    when(() => queue.all()).thenAnswer((_) async => []);

    engine.start();
    await Future<void>.delayed(Duration.zero);
    verify(() => queue.all()).called(1);

    statusController.add(true);
    await Future<void>.delayed(Duration.zero);
    verify(() => queue.all()).called(1);

    await statusController.close();
  });
}
