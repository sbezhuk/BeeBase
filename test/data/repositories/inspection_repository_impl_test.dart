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
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/inspection_repository_impl.dart';
import 'package:beebase/domain/enum/inspection_sync_status.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

PaginatedResponse<InspectionResponse> _paginated(
  List<InspectionResponse> items, {
  required bool hasNext,
  int page = 1,
}) {
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

Matcher _pageRequest(int page) =>
    isA<PageRequest>().having((request) => request.page, 'page', page);

class MockInspectionDataSource extends Mock implements IInspectionDataSource {}

class MockInspectionLocalDataSource extends Mock
    implements LocalDataSource<List<InspectionResponse>> {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

void main() {
  const hiveId = 'hive-1';

  late MockInspectionDataSource dataSource;
  late MockInspectionLocalDataSource localDataSource;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late MockOfflineMutationStore offlineMutationStore;
  late InspectionRepositoryImpl repository;

  final inspectionResponse = InspectionResponse(
    id: 'inspection-1',
    hiveId: hiveId,
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'All looks good',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(
      InspectionRequest(date: DateTime(2026), type: InspectionType.routine, notes: 'notes'),
    );
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(<InspectionResponse>[]);
    registerFallbackValue(
      OfflineOperation(
        id: 'fallback-op',
        entityType: 'inspection',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    List<InspectionResponse> mutateFallback(List<InspectionResponse>? current) =>
        <InspectionResponse>[];
    Object? toJsonFallback(List<InspectionResponse> value) => null;
    List<InspectionResponse> fromJsonFallback(Object? json) => <InspectionResponse>[];
    registerFallbackValue(mutateFallback);
    registerFallbackValue(toJsonFallback);
    registerFallbackValue(fromJsonFallback);
    OfflineOperation operationFallback() => OfflineOperation(
      id: 'fallback-op',
      entityType: 'inspection',
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
    dataSource = MockInspectionDataSource();
    localDataSource = MockInspectionLocalDataSource();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    offlineMutationStore = MockOfflineMutationStore();
    repository = InspectionRepositoryImpl(
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
      final update =
          invocation.positionalArguments.single
              as FutureOr<List<InspectionResponse>> Function(List<InspectionResponse>?);
      await update(await localDataSource.read());
    });
    when(() => operationQueue.all()).thenAnswer((_) async => []);
    when(
      () => offlineMutationStore.saveWithPendingOperation<List<InspectionResponse>>(
        cacheKey: any(named: 'cacheKey'),
        mutate: any(named: 'mutate'),
        toJson: any(named: 'toJson'),
        fromJson: any(named: 'fromJson'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => offlineMutationStore.saveWithConsolidatedOperation<List<InspectionResponse>>(
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
      final mutate =
          invocation.namedArguments[#mutate]
              as List<InspectionResponse> Function(List<InspectionResponse>?);
      mutate(null);
    });
  });

  group('getInspections', () {
    final second = InspectionResponse(
      id: 'inspection-2',
      hiveId: hiveId,
      date: DateTime(2026),
      type: InspectionType.routine,
      notes: 'Test notes',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('first page (page 1) replaces the cache and returns items with hasNext', () async {
      when(
        () => dataSource.getInspections(hiveId, any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([inspectionResponse], hasNext: true));

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((inspection) => inspection.id), ['inspection-1']);
        expect(page.hasNext, isTrue);
      });
    });

    test('load more (page 2) appends onto the existing cache in order', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [inspectionResponse]);
      when(
        () => dataSource.getInspections(hiveId, any(that: _pageRequest(2))),
      ).thenAnswer((_) async => _paginated([second], hasNext: false, page: 2));

      final result = await repository.getInspections(hiveId: hiveId, page: 2, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.map((inspection) => inspection.id), ['inspection-1', 'inspection-2']);
        expect(page.hasNext, isFalse);
      });
    });

    test('falls back to an empty page (not a Failure) when nothing is cached', () async {
      when(
        () => dataSource.getInspections(hiveId, any()),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items, isEmpty);
        expect(page.hasNext, isFalse);
      });
    });

    test('falls back to the cache when a connectivity failure occurs mid-request', () async {
      when(
        () => dataSource.getInspections(hiveId, any()),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));
      when(() => localDataSource.read()).thenAnswer((_) async => [inspectionResponse]);

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold(
        (_) => fail('expected Right'),
        (page) => expect(page.items.single.notes, 'All looks good'),
      );
    });

    test('does not fall back to the cache on a real server failure', () async {
      when(() => dataSource.getInspections(hiveId, any())).thenThrow(
        const ServerException(statusCode: 403, code: 'forbidden', message: 'not allowed'),
      );

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('reads straight from the cache without calling the network when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => [inspectionResponse]);

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items.single.notes, 'All looks good');
        expect(page.hasNext, isFalse);
      });
      verifyNever(() => dataSource.getInspections(any(), any()));
    });

    test('shows an empty page (not a Failure) when offline with nothing cached at all', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => null);

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(page.items, isEmpty);
        expect(page.hasNext, isFalse);
      });
      verifyNever(() => dataSource.getInspections(any(), any()));
    });

    test('keeps a not-yet-synced local inspection alongside a fresh page-1 server list', () async {
      final pendingLocal = InspectionResponse(
        id: 'local-pending-1',
        hiveId: hiveId,
        date: DateTime(2026),
        type: InspectionType.routine,
        notes: 'Test notes',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [pendingLocal]);
      when(
        () => dataSource.getInspections(hiveId, any(that: _pageRequest(1))),
      ).thenAnswer((_) async => _paginated([inspectionResponse], hasNext: false));
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'op-1',
            entityType: 'inspection',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-pending-1',
          ),
        ],
      );

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold((_) => fail('expected Right'), (page) {
        expect(
          page.items.map((inspection) => inspection.id),
          containsAll(['inspection-1', 'local-pending-1']),
        );
        final pending = page.items.firstWhere((inspection) => inspection.id == 'local-pending-1');
        expect(pending.syncStatus, InspectionSyncStatus.pending);
      });
    });
  });

  group('createInspection', () {
    test('sends the request and returns the mapped inspection', () async {
      when(
        () => dataSource.createInspection(hiveId, any()),
      ).thenAnswer((_) async => inspectionResponse);

      final result = await repository.createInspection(
        hiveId: hiveId,
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'All looks good',
      );

      result.fold(
        (_) => fail('expected Right'),
        (inspection) => expect(inspection.notes, 'All looks good'),
      );
      final captured =
          verify(() => dataSource.createInspection(hiveId, captureAny())).captured.single
              as InspectionRequest;
      expect(captured.date, DateTime(2026, 1, 1));
    });

    test(
      'creates locally and enqueues a pending operation carrying the hive id when offline',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);

        final result = await repository.createInspection(
          hiveId: hiveId,
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Test notes',
        );

        late final String returnedId;
        result.fold((_) => fail('expected Right'), (inspection) {
          expect(inspection.hiveId, hiveId);
          expect(inspection.syncStatus, InspectionSyncStatus.pending);
          expect(LocalIdGenerator.isLocal(inspection.id), isTrue);
          returnedId = inspection.id;
        });
        verifyNever(() => dataSource.createInspection(any(), any()));

        final captured = verify(
          () => offlineMutationStore.saveWithPendingOperation<List<InspectionResponse>>(
            cacheKey: captureAny(named: 'cacheKey'),
            mutate: any(named: 'mutate'),
            toJson: any(named: 'toJson'),
            fromJson: any(named: 'fromJson'),
            operation: captureAny(named: 'operation'),
          ),
        ).captured;
        expect(captured[0], inspectionCacheKey);
        final operation = captured[1] as OfflineOperation;
        expect(operation.entityType, 'inspection');
        expect(operation.operationType, OperationType.create);
        expect(operation.localEntityId, returnedId);
        expect(operation.payload['hiveId'], hiveId);
      },
    );

    test(
      'falls back to a local-first create when the network call fails with a connectivity error',
      () async {
        when(
          () => dataSource.createInspection(hiveId, any()),
        ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

        final result = await repository.createInspection(
          hiveId: hiveId,
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Test notes',
        );

        result.fold(
          (_) => fail('expected Right'),
          (inspection) => expect(inspection.syncStatus, InspectionSyncStatus.pending),
        );
      },
    );

    test(
      'links to the parent hive\'s pending CREATE operation when the hive id is itself still local',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        const localHiveId = 'local-hive-1';
        final hiveCreateOp = OfflineOperation(
          id: 'hive-op-1',
          entityType: 'hive',
          operationType: OperationType.create,
          payload: const {'name': 'New Hive'},
          status: OperationStatus.pending,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          localEntityId: localHiveId,
        );
        when(() => operationQueue.all()).thenAnswer((_) async => [hiveCreateOp]);

        await repository.createInspection(
          hiveId: localHiveId,
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Test notes',
        );

        final captured = verify(
          () => offlineMutationStore.saveWithPendingOperation<List<InspectionResponse>>(
            cacheKey: any(named: 'cacheKey'),
            mutate: any(named: 'mutate'),
            toJson: any(named: 'toJson'),
            fromJson: any(named: 'fromJson'),
            operation: captureAny(named: 'operation'),
          ),
        ).captured;
        final operation = captured.single as OfflineOperation;
        expect(operation.dependsOnOperationId, 'hive-op-1');
      },
    );

    test(
      'leaves dependsOnOperationId null when the hive id is already a real backend id',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);

        await repository.createInspection(
          hiveId: hiveId,
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Test notes',
        );

        final captured = verify(
          () => offlineMutationStore.saveWithPendingOperation<List<InspectionResponse>>(
            cacheKey: any(named: 'cacheKey'),
            mutate: any(named: 'mutate'),
            toJson: any(named: 'toJson'),
            fromJson: any(named: 'fromJson'),
            operation: captureAny(named: 'operation'),
          ),
        ).captured;
        final operation = captured.single as OfflineOperation;
        expect(operation.dependsOnOperationId, isNull);
      },
    );
  });

  group('updateInspection', () {
    test('sends the request and returns the mapped inspection', () async {
      when(
        () => dataSource.updateInspection(hiveId, 'inspection-1', any()),
      ).thenAnswer((_) async => inspectionResponse);

      final result = await repository.updateInspection(
        hiveId: hiveId,
        id: 'inspection-1',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'Test notes',
      );

      result.fold(
        (_) => fail('expected Right'),
        (inspection) => expect(inspection.id, 'inspection-1'),
      );
    });

    test(
      'consolidates into the existing pending CREATE instead of erroring on a not-yet-synced local id',
      () async {
        when(() => operationQueue.all()).thenAnswer(
          (_) async => [
            OfflineOperation(
              id: 'op-1',
              entityType: 'inspection',
              operationType: OperationType.create,
              payload: const {},
              status: OperationStatus.pending,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              localEntityId: 'local-pending-1',
            ),
          ],
        );

        final result = await repository.updateInspection(
          hiveId: hiveId,
          id: 'local-pending-1',
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Updated before sync',
        );

        result.fold((_) => fail('expected Right'), (inspection) {
          expect(inspection.notes, 'Updated before sync');
          expect(inspection.syncStatus, InspectionSyncStatus.pending);
        });
        verifyNever(() => dataSource.updateInspection(any(), any(), any()));
      },
    );

    test(
      'a local id with no pending operation is rejected as an invariant-violation safety net',
      () async {
        final result = await repository.updateInspection(
          hiveId: hiveId,
          id: 'local-pending-1',
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Test notes',
        );

        expect(result, isA<Left<Failure, dynamic>>());
        verifyNever(() => dataSource.updateInspection(any(), any(), any()));
      },
    );

    test('updates a synced entity locally and enqueues one pending UPDATE while offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.updateInspection(
        hiveId: hiveId,
        id: 'inspection-1',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'Offline edit',
      );

      result.fold((_) => fail('expected Right'), (inspection) {
        expect(inspection.notes, 'Offline edit');
        expect(inspection.syncStatus, InspectionSyncStatus.pending);
      });
      verifyNever(() => dataSource.updateInspection(any(), any(), any()));
    });

    test(
      'falls back to a local update when the network call fails with a connectivity error',
      () async {
        when(
          () => dataSource.updateInspection(hiveId, 'inspection-1', any()),
        ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

        final result = await repository.updateInspection(
          hiveId: hiveId,
          id: 'inspection-1',
          date: DateTime(2026, 1, 1),
          type: InspectionType.routine,
          notes: 'Test notes',
        );

        result.fold(
          (_) => fail('expected Right'),
          (inspection) => expect(inspection.syncStatus, InspectionSyncStatus.pending),
        );
      },
    );
  });

  group('deleteInspection', () {
    test('completes with Right on success', () async {
      when(() => dataSource.deleteInspection(hiveId, 'inspection-1')).thenAnswer((_) async {});

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result, isA<Right<Failure, void>>());
    });

    test('maps a thrown exception to a Failure', () async {
      when(
        () => dataSource.deleteInspection(hiveId, 'inspection-1'),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result, isA<Left<Failure, void>>());
    });

    test('deletes a never-synced local id locally, without calling the network', () async {
      final result = await repository.deleteInspection(hiveId: hiveId, id: 'local-pending-1');

      expect(result, isA<Right<Failure, void>>());
      verifyNever(() => dataSource.deleteInspection(any(), any()));
    });

    test('cancels the pending CREATE operation when deleting a not-yet-synced local id', () async {
      final pendingCreate = OfflineOperation(
        id: 'op-1',
        entityType: 'inspection',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'local-pending-1',
      );
      when(() => operationQueue.all()).thenAnswer((_) async => [pendingCreate]);
      when(() => operationQueue.remove(any())).thenAnswer((_) async {});

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'local-pending-1');

      expect(result, isA<Right<Failure, void>>());
      verify(() => operationQueue.remove('op-1')).called(1);
    });

    test('blocks deleting a synced id while offline, without calling the network', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => dataSource.deleteInspection(any(), any()));
    });

    test('treats a 404 as an already-completed delete and purges the stale local record', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => [inspectionResponse]);
      when(() => dataSource.deleteInspection(hiveId, 'inspection-1')).thenThrow(
        const ServerException(statusCode: 404, code: 'not_found', message: 'inspection not found'),
      );

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result, isA<Right<Failure, void>>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<InspectionResponse>> Function(List<InspectionResponse>?);
      final written = await update([inspectionResponse]);
      expect(written, isEmpty);
    });

    test('still surfaces a non-404 server error as a failure without purging the cache', () async {
      when(() => dataSource.deleteInspection(hiveId, 'inspection-1')).thenThrow(
        const ServerException(statusCode: 422, code: 'validation_error', message: 'cannot delete'),
      );

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => localDataSource.modify(any()));
    });
  });
}
