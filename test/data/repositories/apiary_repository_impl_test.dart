import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/domain/enum/apiary_sync_status.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

class MockApiaryLocalDataSource extends Mock implements LocalDataSource<List<ApiaryResponse>> {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

void main() {
  late MockApiaryDataSource dataSource;
  late MockApiaryLocalDataSource localDataSource;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late ApiaryListRefreshNotifier refreshNotifier;
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
  });

  setUp(() {
    dataSource = MockApiaryDataSource();
    localDataSource = MockApiaryLocalDataSource();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    refreshNotifier = ApiaryListRefreshNotifier();
    repository = ApiaryRepositoryImpl(
      dataSource: dataSource,
      localDataSource: localDataSource,
      connectivity: connectivity,
      operationQueue: operationQueue,
      refreshNotifier: refreshNotifier,
    );
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => localDataSource.read()).thenAnswer((_) async => null);
    when(() => localDataSource.write(any())).thenAnswer((_) async {});
    when(() => operationQueue.all()).thenAnswer((_) async => []);
    when(() => operationQueue.enqueue(any())).thenAnswer((_) async {});
  });

  tearDown(() => refreshNotifier.dispose());

  group('getApiaries', () {
    test('returns the mapped list on success and writes through to the cache', () async {
      when(() => dataSource.getApiaries()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries();

      result.fold((_) => fail('expected Right'), (apiaries) => expect(apiaries.single.name, 'Back Garden'));
      verify(() => localDataSource.write([apiaryResponse])).called(1);
    });

    test('maps a thrown exception to a Failure when nothing is cached', () async {
      when(() => dataSource.getApiaries()).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.getApiaries();

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('falls back to the cache when a connectivity failure occurs mid-request', () async {
      when(() => dataSource.getApiaries()).thenThrow(const InternalException(ErrorTextRaw('no connection')));
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries();

      result.fold((_) => fail('expected Right'), (apiaries) => expect(apiaries.single.name, 'Back Garden'));
    });

    test('does not fall back to the cache on a real server failure', () async {
      when(
        () => dataSource.getApiaries(),
      ).thenThrow(const ServerException(statusCode: 403, code: 'forbidden', message: 'not allowed'));

      final result = await repository.getApiaries();

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('reads straight from the cache without calling the network when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => localDataSource.read()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries();

      result.fold((_) => fail('expected Right'), (apiaries) => expect(apiaries.single.name, 'Back Garden'));
      verifyNever(() => dataSource.getApiaries());
    });

    test('fails when offline with nothing cached', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.getApiaries();

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.getApiaries());
    });

    test('keeps a not-yet-synced local apiary alongside a fresh server list', () async {
      final pendingLocal = ApiaryResponse(
        id: 'local-pending-1',
        name: 'New Yard',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [pendingLocal]);
      when(() => dataSource.getApiaries()).thenAnswer((_) async => [apiaryResponse]);
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

      final result = await repository.getApiaries();

      result.fold((_) => fail('expected Right'), (apiaries) {
        expect(apiaries.map((apiary) => apiary.id), containsAll(['apiary-1', 'local-pending-1']));
        final pending = apiaries.firstWhere((apiary) => apiary.id == 'local-pending-1');
        expect(pending.syncStatus, ApiarySyncStatus.pending);
        final synced = apiaries.firstWhere((apiary) => apiary.id == 'apiary-1');
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
      when(() => dataSource.getApiaries()).thenAnswer((_) async => [apiaryResponse]);
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

      final result = await repository.getApiaries();

      result.fold((_) => fail('expected Right'), (apiaries) => expect(apiaries.map((apiary) => apiary.id), ['apiary-1']));
    });
  });

  group('getApiary', () {
    test('returns the mapped apiary on success', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);

      final result = await repository.getApiary('apiary-1');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.id, 'apiary-1'));
    });
  });

  group('createApiary', () {
    test('sends the request and returns the mapped apiary', () async {
      when(() => dataSource.createApiary(any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.createApiary(name: 'Back Garden', description: 'A small apiary', location: 'Springfield');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.name, 'Back Garden'));
      final captured = verify(() => dataSource.createApiary(captureAny())).captured.single as ApiaryRequest;
      expect(captured.name, 'Back Garden');
      verifyNever(() => operationQueue.enqueue(any()));
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
      verifyNever(() => operationQueue.enqueue(any()));
    });

    test('creates locally and enqueues a pending operation when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.createApiary(name: 'New Yard', description: 'desc');

      result.fold((_) => fail('expected Right'), (apiary) {
        expect(apiary.name, 'New Yard');
        expect(apiary.syncStatus, ApiarySyncStatus.pending);
        expect(LocalIdGenerator.isLocal(apiary.id), isTrue);
      });
      verifyNever(() => dataSource.createApiary(any()));
      final cached = verify(() => localDataSource.write(captureAny())).captured.single as List<ApiaryResponse>;
      expect(cached.single.name, 'New Yard');
      final enqueued = verify(() => operationQueue.enqueue(captureAny())).captured.single as OfflineOperation;
      expect(enqueued.entityType, 'apiary');
      expect(enqueued.operationType, OperationType.create);
      expect(enqueued.localEntityId, cached.single.id);
    });

    test('falls back to a local-first create when the network call fails with a connectivity error', () async {
      when(() => dataSource.createApiary(any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.createApiary(name: 'New Yard');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.syncStatus, ApiarySyncStatus.pending));
      verify(() => operationQueue.enqueue(any())).called(1);
    });
  });

  group('updateApiary', () {
    test('sends the request and returns the mapped apiary', () async {
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.updateApiary(id: 'apiary-1', name: 'Back Garden');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.id, 'apiary-1'));
    });

    test('rejects a not-yet-synced local id without calling the network', () async {
      final result = await repository.updateApiary(id: 'local-pending-1', name: 'Back Garden');

      expect(result, isA<Left<Failure, dynamic>>());
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

    test('rejects a not-yet-synced local id without calling the network', () async {
      final result = await repository.deleteApiary('local-pending-1');

      expect(result, isA<Left<Failure, void>>());
      verifyNever(() => dataSource.deleteApiary(any()));
    });
  });
}
