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
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/domain/enum/local/apiary_sync_status.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

PaginatedResponse<ApiaryResponse> _paginated(List<ApiaryResponse> items, {required bool hasNext, int page = 1}) {
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

// PageRequest has no value equality (matching ApiaryRequest's DTO
// convention), so a mock stub can't match it by an exact instance — match by
// its page field instead.
Matcher _pageRequest(int page) => isA<PageRequest>().having((request) => request.page, 'page', page);

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

class MockApiaryLocalDataSource extends Mock implements LocalDataSource<List<ApiaryResponse>> {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

void main() {
  late MockApiaryDataSource dataSource;
  late MockApiaryLocalDataSource localDataSource;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late MockOfflineMutationStore offlineMutationStore;
  late ApiaryRepositoryImpl repository;

  final apiaryResponse = ApiaryResponse(
    id: 'apiary-1',
    name: 'Back Garden',
    description: 'A small apiary',
    location: 'Springfield',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(<ApiaryResponse>[]);
    registerFallbackValue(
      OfflineOperation(
        id: 'fallback-op',
        entityType: 'apiary',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    List<ApiaryResponse> mutateFallback(List<ApiaryResponse>? current) => <ApiaryResponse>[];
    Object? toJsonFallback(List<ApiaryResponse> value) => null;
    List<ApiaryResponse> fromJsonFallback(Object? json) => <ApiaryResponse>[];
    registerFallbackValue(mutateFallback);
    registerFallbackValue(toJsonFallback);
    registerFallbackValue(fromJsonFallback);
    OfflineOperation operationFallback() => OfflineOperation(
      id: 'fallback-op',
      entityType: 'apiary',
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
    dataSource = MockApiaryDataSource();
    localDataSource = MockApiaryLocalDataSource();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    offlineMutationStore = MockOfflineMutationStore();
    repository = ApiaryRepositoryImpl(
      dataSource: dataSource,
      localDataSource: localDataSource,
      connectivity: connectivity,
      operationQueue: operationQueue,
      offlineMutationStore: offlineMutationStore,
    );
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => localDataSource.read()).thenAnswer((_) async => null);
    when(() => localDataSource.write(any())).thenAnswer((_) async {});
    // Faithfully runs the callback the repository passes, against whatever
    // `read()` is stubbed to return for the test — mirrors the atomic
    // read-modify-write `SqliteLocalDataSource.modify` actually performs.
    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update = invocation.positionalArguments.single as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      await update(await localDataSource.read());
    });
    when(() => operationQueue.all()).thenAnswer((_) async => []);
    when(
      () => offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
        cacheKey: any(named: 'cacheKey'),
        mutate: any(named: 'mutate'),
        toJson: any(named: 'toJson'),
        fromJson: any(named: 'fromJson'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((_) async {});
    // Mirrors `SqliteOfflineMutationStore.saveWithConsolidatedOperation`
    // closely enough for the repository's purposes: just runs `mutate`
    // against an empty cache so the repository's captured "updated entity"
    // side effect fires, without modeling actual consolidation (that's
    // covered directly in `sqlite_offline_mutation_store_test.dart`).
    when(
      () => offlineMutationStore.saveWithConsolidatedOperation<List<ApiaryResponse>>(
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
      final mutate = invocation.namedArguments[#mutate] as List<ApiaryResponse> Function(List<ApiaryResponse>?);
      mutate(null);
    });
  });

  group('getApiaries', () {
    final second = ApiaryResponse(id: 'apiary-2', name: 'Meadow', createdAt: DateTime(2026), updatedAt: DateTime(2026));

    test('first page (page 1) replaces the cache and returns the mapped items with hasNext', () async {
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([apiaryResponse], hasNext: true));

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((apiary) => apiary.name), ['Back Garden']);
        expect(page.hasNext, isTrue);
      });
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      // Page 1 replaces whatever was cached before, regardless of its contents.
      expect(await update([second]), [apiaryResponse]);
    });

    test('load more (page 2) appends onto the existing cache in order', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(2))),
      ).thenAnswer((_) async => _paginated([second], hasNext: false, page: 2));

      final result = await repository.getApiaries(page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((apiary) => apiary.id), ['apiary-1', 'apiary-2']);
        expect(page.hasNext, isFalse);
      });
    });

    test('load more dedupes an item that appears in both the cache and the fresh page', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(2))),
      ).thenAnswer((_) async => _paginated([apiaryResponse], hasNext: false, page: 2));

      final result = await repository.getApiaries(page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) => expect(page.items.map((apiary) => apiary.id), ['apiary-1']));
    });

    test('maps a thrown exception to a Failure when nothing is cached', () async {
      when(() => dataSource.getApiaries(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('falls back to the cache when a connectivity failure occurs mid-request', () async {
      when(() => dataSource.getApiaries(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) => expect(page.items.single.name, 'Back Garden'));
    });

    test('a network failure on page 2 falls back to the cache accumulated before that request', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(2))),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.getApiaries(page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((apiary) => apiary.id), ['apiary-1']);
        expect(page.hasNext, isFalse);
      });
    });

    test('does not fall back to the cache on a real server failure', () async {
      when(
        () => dataSource.getApiaries(any()),
      ).thenThrow(const ServerException(statusCode: 403, code: 'forbidden', message: 'not allowed'));

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('a server failure on page 2 also propagates without falling back to the cache', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(2))),
      ).thenThrow(const ServerException(statusCode: 403, code: 'forbidden', message: 'not allowed'));

      final result = await repository.getApiaries(page: 2, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('reads straight from the cache without calling the network when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.single.name, 'Back Garden');
        expect(page.hasNext, isFalse);
      });
      verifyNever(() => dataSource.getApiaries(any()));
    });

    test('an offline "load more" attempt never calls the network either', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries(page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) => expect(page.hasNext, isFalse));
      verifyNever(() => dataSource.getApiaries(any()));
    });

    test('fails when offline with nothing cached', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.getApiaries(any()));
    });

    test('keeps a not-yet-synced local apiary alongside a fresh page-1 server list', () async {
      final pendingLocal = ApiaryResponse(
        id: 'local-pending-1',
        name: 'New Yard',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [pendingLocal]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([apiaryResponse], hasNext: false));
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'apiary',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((apiary) => apiary.id), containsAll(['apiary-1', 'local-pending-1']));
        final pending = page.items.firstWhere((apiary) => apiary.id == 'local-pending-1');
        expect(pending.syncStatus, ApiarySyncStatus.pending);
        final synced = page.items.firstWhere((apiary) => apiary.id == 'apiary-1');
        expect(synced.syncStatus, ApiarySyncStatus.synced);
      });
    });

    test('drops a local placeholder once its operation is synced', () async {
      final pendingLocal = ApiaryResponse(
        id: 'local-pending-1',
        name: 'New Yard',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [pendingLocal]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([apiaryResponse], hasNext: false));
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'apiary',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.synced,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) => expect(page.items.map((apiary) => apiary.id), ['apiary-1']));
    });

    test('a load-more (page 2) fetch does not re-add a pending placeholder a second time', () async {
      final pendingLocal = ApiaryResponse(
        id: 'local-pending-1',
        name: 'New Yard',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      // Cache already reflects page 1: the server item plus the pending placeholder.
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse, pendingLocal]);
      when(
        () => dataSource.getApiaries(any(that: _pageRequest(2))),
      ).thenAnswer((_) async => _paginated([second], hasNext: false, page: 2));
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'apiary',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.getApiaries(page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.where((apiary) => apiary.id == 'local-pending-1').length, 1);
        expect(page.items.map((apiary) => apiary.id), ['apiary-1', 'local-pending-1', 'apiary-2']);
      });
    });
  });

  group('getApiary', () {
    test('returns the mapped apiary on success', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);

      final result = await repository.getApiary('apiary-1');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.id, 'apiary-1'));
    });
  });

  group('getCachedApiary', () {
    test('returns the mapped apiary straight from the cache, without calling the network', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getCachedApiary('apiary-1');

      expect(result?.id, 'apiary-1');
      expect(result?.location, 'Springfield');
      verifyNever(() => dataSource.getApiary(any()));
    });

    test('reflects a pending sync status from the operation queue', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'apiary',
            operationType: OperationType.update,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'apiary-1',
          ),
        ],
      );

      final result = await repository.getCachedApiary('apiary-1');

      expect(result?.syncStatus, ApiarySyncStatus.pending);
    });

    test('returns null when the id is not cached', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getCachedApiary('missing-id');

      expect(result, isNull);
    });

    test('returns null when nothing is cached at all', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => null);

      final result = await repository.getCachedApiary('apiary-1');

      expect(result, isNull);
    });
  });

  group('createApiary', () {
    test('sends the request and returns the mapped apiary', () async {
      when(() => dataSource.createApiary(any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.createApiary(name: 'Back Garden', description: 'A small apiary', location: 'Springfield');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.name, 'Back Garden'));
      final captured = verify(() => dataSource.createApiary(captureAny())).captured.single as ApiaryRequest;
      expect(captured.name, 'Back Garden');
      verifyNever(
        () => offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('maps a validation error to a ServerFailure without queuing anything', () async {
      when(() => dataSource.createApiary(any())).thenThrow(
        const ServerException(statusCode: 422, code: 'validation_error', message: 'invalid', fields: {'name': 'name_required'}),
      );

      final result = await repository.createApiary(name: '');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'validation_error')),
        (_) => fail('expected Left'),
      );
      verifyNever(
        () => offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: any(named: 'operation'),
        ),
      );
    });

    test('creates locally and enqueues a pending operation atomically when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.createApiary(name: 'New Yard', description: 'desc');

      late final String returnedId;
      result.fold((_) => fail('expected Right'), (apiary) {
        expect(apiary.name, 'New Yard');
        expect(apiary.syncStatus, ApiarySyncStatus.pending);
        expect(LocalIdGenerator.isLocal(apiary.id), isTrue);
        returnedId = apiary.id;
      });
      verifyNever(() => dataSource.createApiary(any()));

      final capturedCacheKey = verify(
        () => offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
          cacheKey: captureAny(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: captureAny(named: 'operation'),
        ),
      ).captured;
      expect(capturedCacheKey[0], apiaryCacheKey);
      final operation = capturedCacheKey[1] as OfflineOperation;
      expect(operation.entityType, 'apiary');
      expect(operation.operationType, OperationType.create);
      expect(operation.localEntityId, returnedId);
    });

    test('falls back to a local-first create when the network call fails with a connectivity error', () async {
      when(() => dataSource.createApiary(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.createApiary(name: 'New Yard');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.syncStatus, ApiarySyncStatus.pending));
      verify(
        () => offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          operation: any(named: 'operation'),
        ),
      ).called(1);
    });
  });

  group('updateApiary', () {
    test('sends the request and returns the mapped apiary', () async {
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.updateApiary(id: 'apiary-1', name: 'Back Garden');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.id, 'apiary-1'));
    });

    test('consolidates into the existing pending CREATE instead of erroring on a not-yet-synced local id', () async {
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'apiary',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.updateApiary(id: 'local-pending-1', name: 'Renamed Before Sync');

      result.fold((_) => fail('expected Right'), (apiary) {
        expect(apiary.name, 'Renamed Before Sync');
        expect(apiary.syncStatus, ApiarySyncStatus.pending);
      });
      verifyNever(() => dataSource.updateApiary(any(), any()));
      final captured = verify(
        () => offlineMutationStore.saveWithConsolidatedOperation<List<ApiaryResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: any(named: 'entityType'),
          entityId: captureAny(named: 'entityId'),
          operation: any(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      ).captured;
      expect(captured.single, 'local-pending-1');
    });

    test('a local id with no pending operation is rejected as an invariant-violation safety net', () async {
      final result = await repository.updateApiary(id: 'local-pending-1', name: 'Back Garden');

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.updateApiary(any(), any()));
    });

    test('updates a synced entity locally and enqueues one pending UPDATE while offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.updateApiary(id: 'apiary-1', name: 'Renamed Offline');

      result.fold((_) => fail('expected Right'), (apiary) {
        expect(apiary.name, 'Renamed Offline');
        expect(apiary.syncStatus, ApiarySyncStatus.pending);
      });
      verifyNever(() => dataSource.updateApiary(any(), any()));
      final operation =
          verify(
                () => offlineMutationStore.saveWithConsolidatedOperation<List<ApiaryResponse>>(
                  cacheKey: any(named: 'cacheKey'),
                  mutate: any(named: 'mutate'),
                  toJson: any(named: 'toJson'),
                  fromJson: any(named: 'fromJson'),
                  entityType: any(named: 'entityType'),
                  entityId: any(named: 'entityId'),
                  operation: captureAny(named: 'operation'),
                  mergeInto: any(named: 'mergeInto'),
                ),
              ).captured.single
              as OfflineOperation Function();
      expect(operation().operationType, OperationType.update);
      expect(operation().localEntityId, 'apiary-1');
    });

    test('falls back to a local update when the network call fails with a connectivity error', () async {
      when(() => dataSource.updateApiary('apiary-1', any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.updateApiary(id: 'apiary-1', name: 'Renamed');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.syncStatus, ApiarySyncStatus.pending));
      verify(
        () => offlineMutationStore.saveWithConsolidatedOperation<List<ApiaryResponse>>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          operation: any(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      ).called(1);
    });

    test('an existing pending edit routes further edits offline even while online (never bypasses it)', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'apiary',
            operationType: OperationType.update,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'apiary-1',
          ),
        ],
      );

      final result = await repository.updateApiary(id: 'apiary-1', name: 'Second Edit While Online');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.name, 'Second Edit While Online'));
      verifyNever(() => dataSource.updateApiary(any(), any()));
    });
  });

  group('deleteApiary', () {
    test('completes with Right on success', () async {
      when(() => dataSource.deleteApiary('apiary-1')).thenAnswer((_) async {});

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Right<Failure, void>>());
    });

    test('maps a thrown exception to a Failure', () async {
      when(() => dataSource.deleteApiary('apiary-1')).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Left<Failure, void>>());
    });

    test('deletes a never-synced local id locally, without calling the network', () async {
      final result = await repository.deleteApiary('local-pending-1');

      expect(result, isA<Right<Failure, void>>());
      verifyNever(() => dataSource.deleteApiary(any()));
    });

    test('cancels the pending CREATE operation when deleting a not-yet-synced local id', () async {
      final pendingCreate = OfflineOperation(
        id: 'op-1',
        entityType: 'apiary',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'local-pending-1',
      );
      when(() => operationQueue.all()).thenAnswer((_) async => [pendingCreate]);
      when(() => operationQueue.remove(any())).thenAnswer((_) async {});

      final result = await repository.deleteApiary('local-pending-1');

      expect(result, isA<Right<Failure, void>>());
      verify(() => operationQueue.remove('op-1')).called(1);
    });

    test('blocks deleting a synced id while offline, without calling the network', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => dataSource.deleteApiary(any()));
    });

    test('purges the cache and any lingering pending operation after a successful online delete', () async {
      final existing = ApiaryResponse(id: 'apiary-1', name: 'Back Garden', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      when(() => localDataSource.read()).thenAnswer((_) async => [existing]);
      when(() => dataSource.deleteApiary('apiary-1')).thenAnswer((_) async {});
      final staleEdit = OfflineOperation(
        id: 'op-2',
        entityType: 'apiary',
        operationType: OperationType.update,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'apiary-1',
      );
      when(() => operationQueue.all()).thenAnswer((_) async => [staleEdit]);
      when(() => operationQueue.remove(any())).thenAnswer((_) async {});

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Right<Failure, void>>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      final written = await update([existing]);
      expect(written, isEmpty);
      verify(() => operationQueue.remove('op-2')).called(1);
    });

    test('treats a 404 as an already-completed delete and purges the stale local record', () async {
      final existing = ApiaryResponse(id: 'apiary-1', name: 'Back Garden', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      when(() => localDataSource.read()).thenAnswer((_) async => [existing]);
      when(
        () => dataSource.deleteApiary('apiary-1'),
      ).thenThrow(const ServerException(statusCode: 404, code: 'not_found', message: 'apiary not found'));

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Right<Failure, void>>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      final written = await update([existing]);
      expect(written, isEmpty);
    });

    test('still surfaces a non-404 server error as a failure without purging the cache', () async {
      when(
        () => dataSource.deleteApiary('apiary-1'),
      ).thenThrow(const ServerException(statusCode: 422, code: 'validation_error', message: 'cannot delete'));

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => localDataSource.modify(any()));
    });
  });
}
