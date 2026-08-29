import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/offline/sqlite_operation_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/sqlite_test_helper.dart';

OfflineOperation _operation(String id, {String? localEntityId, OperationStatus status = OperationStatus.pending}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'Test'},
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
  );
}

void main() {
  test('all() returns an empty list when nothing was ever stored', () async {
    final database = await openTestDatabase();
    final queue = SqliteOperationQueue(database: database, changeNotifier: OfflineOperationsChangeNotifier());

    expect(await queue.all(), isEmpty);
  });

  test('enqueue appends an operation, in insertion order', () async {
    final database = await openTestDatabase();
    final queue = SqliteOperationQueue(database: database, changeNotifier: OfflineOperationsChangeNotifier());

    await queue.enqueue(_operation('op-1'));
    await queue.enqueue(_operation('op-2'));

    final all = await queue.all();
    expect(all.map((operation) => operation.id), ['op-1', 'op-2']);
  });

  test('enqueue round-trips every field', () async {
    final database = await openTestDatabase();
    final queue = SqliteOperationQueue(database: database, changeNotifier: OfflineOperationsChangeNotifier());
    final operation = OfflineOperation(
      id: 'op-1',
      entityType: 'apiary',
      operationType: OperationType.create,
      payload: const {'name': 'Test', 'lat': 1.5},
      status: OperationStatus.pending,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 3),
      retryCount: 2,
      lastError: 'boom',
      localEntityId: 'local-1',
      dependsOnOperationId: 'op-0',
    );

    await queue.enqueue(operation);

    final stored = (await queue.all()).single;
    expect(stored.entityType, 'apiary');
    expect(stored.operationType, OperationType.create);
    expect(stored.payload, {'name': 'Test', 'lat': 1.5});
    expect(stored.status, OperationStatus.pending);
    expect(stored.createdAt, DateTime(2026, 1, 2));
    expect(stored.updatedAt, DateTime(2026, 1, 3));
    expect(stored.retryCount, 2);
    expect(stored.lastError, 'boom');
    expect(stored.localEntityId, 'local-1');
    expect(stored.dependsOnOperationId, 'op-0');
  });

  test('update replaces only the matching operation', () async {
    final database = await openTestDatabase();
    final queue = SqliteOperationQueue(database: database, changeNotifier: OfflineOperationsChangeNotifier());
    await queue.enqueue(_operation('op-1'));
    await queue.enqueue(_operation('op-2'));

    await queue.update(_operation('op-1', status: OperationStatus.synced));

    final all = await queue.all();
    expect(all.firstWhere((operation) => operation.id == 'op-1').status, OperationStatus.synced);
    expect(all.firstWhere((operation) => operation.id == 'op-2').status, OperationStatus.pending);
  });

  test('remove drops only the matching operation', () async {
    final database = await openTestDatabase();
    final queue = SqliteOperationQueue(database: database, changeNotifier: OfflineOperationsChangeNotifier());
    await queue.enqueue(_operation('op-1'));
    await queue.enqueue(_operation('op-2'));

    await queue.remove('op-1');

    final all = await queue.all();
    expect(all.map((operation) => operation.id), ['op-2']);
  });

  test('changes fires after enqueue/update/remove', () async {
    final database = await openTestDatabase();
    final notifier = OfflineOperationsChangeNotifier();
    final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);
    final events = <void>[];
    final subscription = queue.changes.listen(events.add);

    await queue.enqueue(_operation('op-1'));
    await queue.update(_operation('op-1', status: OperationStatus.synced));
    await queue.remove('op-1');
    await Future<void>.delayed(Duration.zero);

    expect(events.length, 3);
    await subscription.cancel();
  });
}
