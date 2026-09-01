import 'dart:async';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/domain/enum/hive_sync_status.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

PaginatedResponse<HiveResponse> _paginated(List<HiveResponse> items, {required bool hasNext, int page = 1}) {
  return PaginatedResponse(
    items: items,
    pagination: PaginationMeta(
      page: page,
      limit: 20,
      total: items.length,
      totalPages: 1,
      hasNext: hasNext,
      hasPrevious: page > 1,
    ),
  );
}

Matcher _pageRequest(int page) => isA<PageRequest>().having((request) => request.page, 'page', page);

class MockHiveDataSource extends Mock implements IHiveDataSource {}

class MockHiveLocalDataSource extends Mock implements LocalDataSource<List<HiveResponse>> {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

void main() {
  const apiaryId = 'apiary-1';

  late MockHiveDataSource dataSource;
  late MockHiveLocalDataSource localDataSource;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late MockOfflineMutationStore offlineMutationStore;
  late HiveRepositoryImpl repository;

  final hiveResponse = HiveResponse(
    id: 'hive-1',
    apiaryId: apiaryId,
    name: 'Hive 1',
    notes: 'A busy hive',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(const HiveRequest(name: 'fallback'));
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(<HiveResponse>[]);
    registerFallbackValue(
      OfflineOperation(
        id: 'fallback-op',
        entityType: 'hive',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    List<HiveResponse> mutateFallback(List<HiveResponse>? current) => <HiveResponse>[];
    Object? toJsonFallback(List<HiveResponse> value) => null;
    List<HiveResponse> fromJsonFallback(Object? json) => <HiveResponse>[];
    registerFallbackValue(mutateFallback);
    registerFallbackValue(toJsonFallback);
    registerFallbackValue(fromJsonFallback);
    OfflineOperation operationFallback() => OfflineOperation(
      id: 'fallback-op',
      entityType: 'hive',
      operationType: OperationType.update,
      payload: const {},
      status: OperationStatus.pending,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    OfflineOperation mergeIntoFallback(OfflineOperation existing) => existing;
    registerFallbackValue(operationFallback);
    registerFallbackValue(mergeIntoFallback);
  });

  setUp(() {
    dataSource = MockHiveDataSource();
    localDataSource = MockHiveLocalDataSource();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    offlineMutationStore = MockOfflineMutationStore();
    repository = HiveRepositoryImpl(
      dataSource: dataSource,
      localDataSource: localDataSource,
      connectivity: connectivity,
      operationQueue: operationQueue,
      offlineMutationStore: offlineMutationStore,
    );
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => localDataSource.read()).thenAnswer((_) async => null);
    when(() => localDataSource.write(any())).thenAnswer((_) async {});
    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update = invocation.positionalArguments.single as FutureOr<List<HiveResponse>> Function(List<HiveResponse>?);
      await update(await localDataSource.read());
    });
    when(() => operationQueue.all()).thenAnswer((_) async => []);
    when(
      () => offlineMutationStore.saveWithPendingOperation<List<HiveResponse>>(
        cacheKey: any(named: 'cacheKey'),
        mutate: any(named: 'mutate'),
        toJson: any(named: 'toJson'),
        fromJson: any(named: 'fromJson'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => offlineMutationStore.saveWithConsolidatedOperation<List<HiveResponse>>(
        cacheKey: any(named: 'cacheKey'),
        mutate: any(named: 'mutate'),
        toJson: any(named: 'toJson'),
        fromJson: any(named: 'fromJson'),
        entityType: any(named: 'entityType'),
        entityId: any(named: 'entityId'),
        operation: any(named: 'operation'),
        mergeInto: any(named: 'mergeInto'),
      ),
    ).thenAnswer((invocation) async {
      final mutate = invocation.namedArguments[#mutate] as List<HiveResponse> Function(List<HiveResponse>?);
      mutate(null);
    });
  });

  group('getHives', () {
    final second = HiveResponse(
      id: 'hive-2',
      apiaryId: apiaryId,
      name: 'Hive 2',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('first page (page 1) replaces the cache and returns items filtered to this apiary with hasNext', () async {
      when(
        () => dataSource.getHives(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([hiveResponse], hasNext: true));

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((hive) => hive.name), ['Hive 1']);
        expect(page.hasNext, isTrue);
      });
    });

    test('the global (unfiltered) fetched page still filters the returned items down to this apiary', () async {
      final otherApiaryHive = HiveResponse(
        id: 'hive-99',
        apiaryId: 'apiary-2',
        name: 'Foreign Hive',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => dataSource.getHives(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([hiveResponse, otherApiaryHive], hasNext: false));

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) => expect(page.items.map((hive) => hive.id), ['hive-1']));
    });

    test('load more (page 2) appends onto the existing cache in order', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [hiveResponse]);
      when(
        () => dataSource.getHives(any(that: _pageRequest(2))),
      ).thenAnswer((_) async => _paginated([second], hasNext: false, page: 2));

      final result = await repository.getHives(apiaryId: apiaryId, page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((hive) => hive.id), ['hive-1', 'hive-2']);
        expect(page.hasNext, isFalse);
      });
    });

    test('maps a thrown exception to a Failure when nothing is cached', () async {
      when(() => dataSource.getHives(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('falls back to the cache when a connectivity failure occurs mid-request', () async {
      when(() => dataSource.getHives(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));
      when(() => localDataSource.read()).thenAnswer((_) async => [hiveResponse]);

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) => expect(page.items.single.name, 'Hive 1'));
    });

    test('does not fall back to the cache on a real server failure', () async {
      when(
        () => dataSource.getHives(any()),
      ).thenThrow(const ServerException(statusCode: 403, code: 'forbidden', message: 'not allowed'));

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('reads straight from the cache without calling the network when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => [hiveResponse]);

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.single.name, 'Hive 1');
        expect(page.hasNext, isFalse);
      });
      verifyNever(() => dataSource.getHives(any()));
    });

    test('returns an empty page when offline with a populated cache holding no hives for this apiary', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      final otherApiaryHive = HiveResponse(
        id: 'hive-99',
        apiaryId: 'apiary-2',
        name: 'Foreign Hive',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [otherApiaryHive]);

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items, isEmpty);
        expect(page.hasNext, isFalse);
      });
      verifyNever(() => dataSource.getHives(any()));
    });

    test('fails when offline with nothing cached at all', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => null);

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.getHives(any()));
    });

    test('keeps a not-yet-synced local hive alongside a fresh page-1 server list', () async {
      final pendingLocal = HiveResponse(
        id: 'local-pending-1',
        apiaryId: apiaryId,
        name: 'New Hive',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [pendingLocal]);
      when(
        () => dataSource.getHives(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([hiveResponse], hasNext: false));
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'hive',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.getHives(apiaryId: apiaryId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((hive) => hive.id), containsAll(['hive-1', 'local-pending-1']));
        final pending = page.items.firstWhere((hive) => hive.id == 'local-pending-1');
        expect(pending.syncStatus, HiveSyncStatus.pending);
      });
    });
  });

  group('getHiveCounts', () {
    final otherApiaryHive = HiveResponse(
      id: 'hive-99',
      apiaryId: 'apiary-2',
      name: 'Foreign Hive',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('tallies a single page of hives by apiary id', () async {
      when(
        () => dataSource.getHives(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([hiveResponse, otherApiaryHive], hasNext: false));

      final result = await repository.getHiveCounts();

      result.fold((_) => fail('expected Right'), (counts) {
        expect(counts[apiaryId], 1);
        expect(counts['apiary-2'], 1);
      });
    });

    test('walks every page before tallying, since the endpoint has no apiary filter or total', () async {
      final second = HiveResponse(
        id: 'hive-2',
        apiaryId: apiaryId,
        name: 'Hive 2',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => dataSource.getHives(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([hiveResponse], hasNext: true));
      when(
        () => dataSource.getHives(any(that: _pageRequest(2))),
      ).thenAnswer((_) async => _paginated([second, otherApiaryHive], hasNext: false, page: 2));

      final result = await repository.getHiveCounts();

      result.fold((_) => fail('expected Right'), (counts) {
        expect(counts[apiaryId], 2);
        expect(counts['apiary-2'], 1);
      });
      verify(() => dataSource.getHives(any(that: _pageRequest(1)))).called(1);
      verify(() => dataSource.getHives(any(that: _pageRequest(2)))).called(1);
    });

    test('an apiary with no hives is simply absent from the map, not present with a zero', () async {
      when(
        () => dataSource.getHives(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([otherApiaryHive], hasNext: false));

      final result = await repository.getHiveCounts();

      result.fold((_) => fail('expected Right'), (counts) => expect(counts.containsKey(apiaryId), isFalse));
    });

    test('falls back to the cache when a connectivity failure occurs mid-request', () async {
      when(() => dataSource.getHives(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));
      when(() => localDataSource.read()).thenAnswer((_) async => [hiveResponse, otherApiaryHive]);

      final result = await repository.getHiveCounts();

      result.fold((_) => fail('expected Right'), (counts) {
        expect(counts[apiaryId], 1);
        expect(counts['apiary-2'], 1);
      });
    });

    test('does not fall back to the cache on a real server failure', () async {
      when(
        () => dataSource.getHives(any()),
      ).thenThrow(const ServerException(statusCode: 403, code: 'forbidden', message: 'not allowed'));

      final result = await repository.getHiveCounts();

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('reads straight from the cache without calling the network when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => [hiveResponse]);

      final result = await repository.getHiveCounts();

      result.fold((_) => fail('expected Right'), (counts) => expect(counts[apiaryId], 1));
      verifyNever(() => dataSource.getHives(any()));
    });

    test('returns an empty map when offline with a populated cache holding no hives at all', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => []);

      final result = await repository.getHiveCounts();

      result.fold((_) => fail('expected Right'), (counts) => expect(counts, isEmpty));
    });

    test('fails when offline with nothing cached at all', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => null);

      final result = await repository.getHiveCounts();

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.getHives(any()));
    });
  });

  group('getHive', () {
    test('returns the mapped hive on success', () async {
      when(() => dataSource.getHive('hive-1')).thenAnswer((_) async => hiveResponse);

      final result = await repository.getHive('hive-1');

      result.fold((_) => fail('expected Right'), (hive) => expect(hive.id, 'hive-1'));
    });
  });

  group('createHive', () {
    test('sends the request with the apiary id and returns the mapped hive', () async {
      when(() => dataSource.createHive(any(), apiaryId: apiaryId)).thenAnswer((_) async => hiveResponse);

      final result = await repository.createHive(apiaryId: apiaryId, name: 'Hive 1', notes: 'A busy hive');

      result.fold((_) => fail('expected Right'), (hive) => expect(hive.name, 'Hive 1'));
      final captured = verify(() => dataSource.createHive(captureAny(), apiaryId: apiaryId)).captured.single as HiveRequest;
      expect(captured.name, 'Hive 1');
    });

    test('creates locally and enqueues a pending operation carrying the apiary id when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.createHive(apiaryId: apiaryId, name: 'New Hive');

      late final String returnedId;
      result.fold((_) => fail('expected Right'), (hive) {
        expect(hive.name, 'New Hive');
        expect(hive.apiaryId, apiaryId);
        expect(hive.syncStatus, HiveSyncStatus.pending);
        expect(LocalIdGenerator.isLocal(hive.id), isTrue);
        returnedId = hive.id;
      });
      verifyNever(() => dataSource.createHive(any(), apiaryId: any(named: 'apiaryId')));

      final captured = verify(
        () => offlineMutationStore.saveWithPendingOperation<List<HiveResponse>>(
          cacheKey: captureAny(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: captureAny(named: 'operation'),
        ),
      ).captured;
      expect(captured[0], hiveCacheKey);
      final operation = captured[1] as OfflineOperation;
      expect(operation.entityType, 'hive');
      expect(operation.operationType, OperationType.create);
      expect(operation.localEntityId, returnedId);
      expect(operation.payload['apiaryId'], apiaryId);
    });

    test('falls back to a local-first create when the network call fails with a connectivity error', () async {
      when(
        () => dataSource.createHive(any(), apiaryId: apiaryId),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.createHive(apiaryId: apiaryId, name: 'New Hive');

      result.fold((_) => fail('expected Right'), (hive) => expect(hive.syncStatus, HiveSyncStatus.pending));
    });

    test('links to the parent apiary\'s pending CREATE operation when the apiary id is itself still local', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      const localApiaryId = 'local-apiary-1';
      final apiaryCreateOp = OfflineOperation(
        id: 'apiary-op-1',
        entityType: 'apiary',
        operationType: OperationType.create,
        payload: const {'name': 'New Apiary'},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: localApiaryId,
      );
      when(() => operationQueue.all()).thenAnswer((_) async => [apiaryCreateOp]);

      await repository.createHive(apiaryId: localApiaryId, name: 'New Hive');

      final captured = verify(
        () => offlineMutationStore.saveWithPendingOperation<List<HiveResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: captureAny(named: 'operation'),
        ),
      ).captured;
      final operation = captured.single as OfflineOperation;
      expect(operation.dependsOnOperationId, 'apiary-op-1');
    });

    test('leaves dependsOnOperationId null when the apiary id is already a real backend id', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      await repository.createHive(apiaryId: apiaryId, name: 'New Hive');

      final captured = verify(
        () => offlineMutationStore.saveWithPendingOperation<List<HiveResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: captureAny(named: 'operation'),
        ),
      ).captured;
      final operation = captured.single as OfflineOperation;
      expect(operation.dependsOnOperationId, isNull);
    });
  });

  group('updateHive', () {
    test('sends the request and returns the mapped hive, without an apiary id in the request', () async {
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => hiveResponse);

      final result = await repository.updateHive(apiaryId: apiaryId, id: 'hive-1', name: 'Hive 1');

      result.fold((_) => fail('expected Right'), (hive) => expect(hive.id, 'hive-1'));
    });

    test('consolidates into the existing pending CREATE instead of erroring on a not-yet-synced local id', () async {
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'hive',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.updateHive(apiaryId: apiaryId, id: 'local-pending-1', name: 'Renamed Before Sync');

      result.fold((_) => fail('expected Right'), (hive) {
        expect(hive.name, 'Renamed Before Sync');
        expect(hive.syncStatus, HiveSyncStatus.pending);
      });
      verifyNever(() => dataSource.updateHive(any(), any()));
    });

    test('a local id with no pending operation is rejected as an invariant-violation safety net', () async {
      final result = await repository.updateHive(apiaryId: apiaryId, id: 'local-pending-1', name: 'Hive 1');

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.updateHive(any(), any()));
    });

    test('updates a synced entity locally and enqueues one pending UPDATE while offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.updateHive(apiaryId: apiaryId, id: 'hive-1', name: 'Renamed Offline');

      result.fold((_) => fail('expected Right'), (hive) {
        expect(hive.name, 'Renamed Offline');
        expect(hive.syncStatus, HiveSyncStatus.pending);
      });
      verifyNever(() => dataSource.updateHive(any(), any()));
    });

    test('falls back to a local update when the network call fails with a connectivity error', () async {
      when(() => dataSource.updateHive('hive-1', any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.updateHive(apiaryId: apiaryId, id: 'hive-1', name: 'Renamed');

      result.fold((_) => fail('expected Right'), (hive) => expect(hive.syncStatus, HiveSyncStatus.pending));
    });
  });

  group('deleteHive', () {
    test('completes with Right on success', () async {
      when(() => dataSource.deleteHive('hive-1')).thenAnswer((_) async {});

      final result = await repository.deleteHive('hive-1');

      expect(result, isA<Right<Failure, void>>());
    });

    test('maps a thrown exception to a Failure', () async {
      when(() => dataSource.deleteHive('hive-1')).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.deleteHive('hive-1');

      expect(result, isA<Left<Failure, void>>());
    });

    test('deletes a never-synced local id locally, without calling the network', () async {
      final result = await repository.deleteHive('local-pending-1');

      expect(result, isA<Right<Failure, void>>());
      verifyNever(() => dataSource.deleteHive(any()));
    });

    test('cancels the pending CREATE operation when deleting a not-yet-synced local id', () async {
      final pendingCreate = OfflineOperation(
        id: 'op-1',
        entityType: 'hive',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'local-pending-1',
      );
      when(() => operationQueue.all()).thenAnswer((_) async => [pendingCreate]);
      when(() => operationQueue.remove(any())).thenAnswer((_) async {});

      final result = await repository.deleteHive('local-pending-1');

      expect(result, isA<Right<Failure, void>>());
      verify(() => operationQueue.remove('op-1')).called(1);
    });

    test('blocks deleting a synced id while offline, without calling the network', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.deleteHive('hive-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => dataSource.deleteHive(any()));
    });

    test('treats a 404 as an already-completed delete and purges the stale local record', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [hiveResponse]);
      when(
        () => dataSource.deleteHive('hive-1'),
      ).thenThrow(const ServerException(statusCode: 404, code: 'not_found', message: 'hive not found'));

      final result = await repository.deleteHive('hive-1');

      expect(result, isA<Right<Failure, void>>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<HiveResponse>> Function(List<HiveResponse>?);
      final written = await update([hiveResponse]);
      expect(written, isEmpty);
    });

    test('still surfaces a non-404 server error as a failure without purging the cache', () async {
      when(
        () => dataSource.deleteHive('hive-1'),
      ).thenThrow(const ServerException(statusCode: 422, code: 'validation_error', message: 'cannot delete'));

      final result = await repository.deleteHive('hive-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => localDataSource.modify(any()));
    });
  });
}
