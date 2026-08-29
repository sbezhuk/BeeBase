import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/offline/sqlite_offline_mutation_store.dart';
import 'package:beebase/core/offline/sqlite_operation_queue.dart';
import 'package:beebase/data/data_source/sqlite_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/sqlite_test_helper.dart';

OfflineOperation _operation(String id) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'New Yard'},
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: 'local-1',
  );
}

void main() {
  test('saves the cache entry and enqueues the operation together', () async {
    final database = await openTestDatabase();
    final notifier = OfflineOperationsChangeNotifier();
    final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
    final localDataSource = SqliteLocalDataSource<List<String>>(
      database: database,
      key: 'names',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<String>(),
    );
    final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);

    await store.saveWithPendingOperation<List<String>>(
      cacheKey: 'names',
      mutate: (current) => [...?current, 'New Yard'],
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<String>(),
      operation: _operation('op-1'),
    );

    expect(await localDataSource.read(), ['New Yard']);
    expect((await queue.all()).single.id, 'op-1');
  });

  test('applies mutate against the current cache value, not a stale one', () async {
    final database = await openTestDatabase();
    final notifier = OfflineOperationsChangeNotifier();
    final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
    final localDataSource = SqliteLocalDataSource<List<String>>(
      database: database,
      key: 'names',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<String>(),
    );
    await localDataSource.write(['Existing Yard']);

    await store.saveWithPendingOperation<List<String>>(
      cacheKey: 'names',
      mutate: (current) => [...?current, 'New Yard'],
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<String>(),
      operation: _operation('op-1'),
    );

    expect(await localDataSource.read(), ['Existing Yard', 'New Yard']);
  });

  test('a failure inside mutate leaves neither the cache nor the operation persisted', () async {
    final database = await openTestDatabase();
    final notifier = OfflineOperationsChangeNotifier();
    final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
    final localDataSource = SqliteLocalDataSource<List<String>>(
      database: database,
      key: 'names',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<String>(),
    );
    final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);

    await expectLater(
      store.saveWithPendingOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => throw StateError('boom'),
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        operation: _operation('op-1'),
      ),
      throwsStateError,
    );

    expect(await localDataSource.read(), isNull);
    expect(await queue.all(), isEmpty);
  });
}
