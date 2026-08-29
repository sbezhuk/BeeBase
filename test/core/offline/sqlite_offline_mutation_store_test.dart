import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/offline/sqlite_offline_mutation_store.dart';
import 'package:beebase/core/offline/sqlite_operation_queue.dart';
import 'package:beebase/data/data_source/sqlite_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/sqlite_test_helper.dart';

OfflineOperation _operation(String id, {String localEntityId = 'apiary-1', OperationStatus status = OperationStatus.pending}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'New Yard'},
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
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

  group('saveWithConsolidatedOperation', () {
    test('enqueues a new operation when nothing pending exists for the entity yet', () async {
      final database = await openTestDatabase();
      final notifier = OfflineOperationsChangeNotifier();
      final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
      final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);

      await store.saveWithConsolidatedOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => [...?current, 'New Yard'],
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        entityType: 'apiary',
        entityId: 'apiary-1',
        operation: () => _operation('op-1'),
        mergeInto: (existing) => fail('should not merge — nothing pending yet'),
      );

      final all = await queue.all();
      expect(all.single.id, 'op-1');
      expect(all.single.version, 0);
    });

    test('a second edit for the same entity folds into the existing row instead of adding a new one', () async {
      final database = await openTestDatabase();
      final notifier = OfflineOperationsChangeNotifier();
      final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
      final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);
      final localDataSource = SqliteLocalDataSource<List<String>>(
        database: database,
        key: 'names',
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
      );
      await store.saveWithConsolidatedOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => ['New Yard'],
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        entityType: 'apiary',
        entityId: 'apiary-1',
        operation: () => _operation('op-1'),
        mergeInto: (existing) => fail('should not merge on the first save'),
      );

      await store.saveWithConsolidatedOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => ['Renamed Yard'],
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        entityType: 'apiary',
        entityId: 'apiary-1',
        operation: () => fail('should not enqueue a second operation'),
        mergeInto: (existing) => existing.copyWith(payload: const {'name': 'Renamed Yard'}, version: existing.version + 1),
      );

      final all = await queue.all();
      expect(all.length, 1);
      expect(all.single.id, 'op-1');
      expect(all.single.version, 1);
      expect(all.single.payload, {'name': 'Renamed Yard'});
      expect(await localDataSource.read(), ['Renamed Yard']);
    });

    test('a different entity id gets its own independent operation', () async {
      final database = await openTestDatabase();
      final notifier = OfflineOperationsChangeNotifier();
      final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
      final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);
      await store.saveWithConsolidatedOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => ['New Yard'],
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        entityType: 'apiary',
        entityId: 'apiary-1',
        operation: () => _operation('op-1'),
        mergeInto: (existing) => fail('should not merge'),
      );

      await store.saveWithConsolidatedOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => [...?current, 'Meadow'],
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        entityType: 'apiary',
        entityId: 'apiary-2',
        operation: () => _operation('op-2', localEntityId: 'apiary-2'),
        mergeInto: (existing) => fail('should not merge — different entity'),
      );

      final all = await queue.all();
      expect(all.map((operation) => operation.id), ['op-1', 'op-2']);
    });

    test('an already-synced operation for the entity is ignored — a fresh one is enqueued instead', () async {
      final database = await openTestDatabase();
      final notifier = OfflineOperationsChangeNotifier();
      final store = SqliteOfflineMutationStore(database: database, changeNotifier: notifier);
      final queue = SqliteOperationQueue(database: database, changeNotifier: notifier);
      await queue.enqueue(_operation('op-1', status: OperationStatus.synced));

      await store.saveWithConsolidatedOperation<List<String>>(
        cacheKey: 'names',
        mutate: (current) => [...?current, 'New Yard'],
        toJson: (value) => value,
        fromJson: (json) => (json as List<dynamic>).cast<String>(),
        entityType: 'apiary',
        entityId: 'apiary-1',
        operation: () => _operation('op-2'),
        mergeInto: (existing) => fail('should not merge into a synced operation'),
      );

      final all = await queue.all();
      expect(all.map((operation) => operation.id), ['op-1', 'op-2']);
      expect(all.last.status, OperationStatus.pending);
    });
  });
}
