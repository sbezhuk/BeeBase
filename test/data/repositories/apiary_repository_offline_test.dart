import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

class MockApiaryLocalDataSource extends Mock implements IApiaryLocalDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockApiaryDataSource remoteDataSource;
  late MockApiaryLocalDataSource localDataSource;
  late MockNetworkInfo networkInfo;
  late ApiaryRepositoryImpl repository;

  final sampleResponse = ApiaryResponse(
    id: 'server-1',
    name: 'Online Apiary',
    description: 'Description',
    location: 'Location',
    lat: 50.0,
    lon: 30.0,
    images: const [
      EntityImageResponse(id: 'img-1', imageUrl: 'https://example.com/1.jpg'),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleOfflineApiary = Apiary(
    id: 'local-123',
    localId: 'local-123',
    name: 'Offline Apiary',
    description: 'Local desc',
    location: 'Local loc',
    lat: 50.0,
    lon: 30.0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final sampleSyncedApiary = Apiary(
    id: 'server-1',
    localId: 'server-1',
    serverId: 'server-1',
    name: 'Online Apiary',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.synced,
  );

  setUpAll(() {
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(sampleOfflineApiary);
  });

  setUp(() {
    remoteDataSource = MockApiaryDataSource();
    localDataSource = MockApiaryLocalDataSource();
    networkInfo = MockNetworkInfo();
    repository = ApiaryRepositoryImpl(
      dataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
  });

  group('ApiaryRepositoryImpl - Online operations', () {
    setUp(() {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    });

    test('online create calls remote API and caches to local SQLite', () async {
      when(() => remoteDataSource.createApiary(any()))
          .thenAnswer((_) async => sampleResponse);
      when(() => localDataSource.saveServerApiaries(any()))
          .thenAnswer((_) async {});

      final result = await repository.createApiary(name: 'Online Apiary');

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (apiary) {
        expect(apiary.id, 'server-1');
        expect(apiary.name, 'Online Apiary');
      });
      verify(() => remoteDataSource.createApiary(any())).called(1);
      verify(() => localDataSource.saveServerApiaries(any())).called(1);
    });

    test('online getApiaries fetches remote, caches to SQLite and includes pendingCreates on page 1', () async {
      when(() => remoteDataSource.getApiaries(any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [sampleResponse],
          pagination: const PaginationMeta(
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );
      when(() => localDataSource.saveServerApiaries(any()))
          .thenAnswer((_) async {});
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [sampleOfflineApiary]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (page) {
        // Includes pendingCreate + serverItems
        expect(page.items.length, 2);
        expect(page.items[0].id, 'local-123');
        expect(page.items[1].id, 'server-1');
      });
      verify(() => remoteDataSource.getApiaries(any())).called(1);
      verify(() => localDataSource.saveServerApiaries(any())).called(1);
    });

    test(
        'online getApiaries replaces server item with local pendingUpdate version when back online',
        () async {
      // Server returns the old (pre-edit) version of apiary 'server-1'.
      when(() => remoteDataSource.getApiaries(any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [sampleResponse],
          pagination: const PaginationMeta(
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );
      when(() => localDataSource.saveServerApiaries(any()))
          .thenAnswer((_) async {});

      // Local DB has a pendingUpdate version with the user's offline edits.
      final pendingUpdateApiary = Apiary(
        id: 'server-1',
        localId: 'local-server-1',
        serverId: 'server-1',
        name: 'Offline Edited Name',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        syncStatus: SyncStatus.pendingUpdate,
      );
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingUpdateApiary]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (page) {
        expect(page.items.length, 1);
        // The local edited version should be returned, not the server version.
        expect(page.items[0].name, 'Offline Edited Name');
        expect(page.items[0].syncStatus, SyncStatus.pendingUpdate);
      });
    });

    test(
        'online getApiaries hides a pendingDelete server item from the list',
        () async {
      when(() => remoteDataSource.getApiaries(any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [sampleResponse],
          pagination: const PaginationMeta(
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );
      when(() => localDataSource.saveServerApiaries(any()))
          .thenAnswer((_) async {});

      final pendingDeleteApiary = Apiary(
        id: 'server-1',
        localId: 'local-server-1',
        serverId: 'server-1',
        name: 'Online Apiary',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.pendingDelete,
      );
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingDeleteApiary]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (page) {
        // The pendingDelete item should be hidden from the list.
        expect(page.items, isEmpty);
      });
    });

    test('online getApiary returns local pendingUpdate version instead of server version',
        () async {
      final pendingUpdateApiary = Apiary(
        id: 'server-1',
        localId: 'local-server-1',
        serverId: 'server-1',
        name: 'Locally Edited Name',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        syncStatus: SyncStatus.pendingUpdate,
      );
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => pendingUpdateApiary);

      final result = await repository.getApiary('server-1');

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (apiary) {
        expect(apiary.name, 'Locally Edited Name');
        expect(apiary.syncStatus, SyncStatus.pendingUpdate);
      });
      // Remote API should not be called — local pending version is returned.
      verifyNever(() => remoteDataSource.getApiary(any()));
    });

    test('online getApiaries falls back to SQLite cache if remote fails', () async {
      when(() => remoteDataSource.getApiaries(any())).thenThrow(
        const ServerException(statusCode: 500, code: 'server_error', message: 'Down'),
      );
      when(() => localDataSource.getActiveApiaries(page: 1, limit: 20))
          .thenAnswer((_) async => [sampleSyncedApiary]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (page) {
        expect(page.items.length, 1);
        expect(page.items.first.id, 'server-1');
      });
    });

    test('online delete calls remote API and deletes permanently from SQLite', () async {
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => sampleSyncedApiary);
      when(() => remoteDataSource.deleteApiary('server-1'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteApiaryPermanently('server-1'))
          .thenAnswer((_) async {});

      final result = await repository.deleteApiary('server-1');

      expect(result.isRight, isTrue);
      verify(() => remoteDataSource.deleteApiary('server-1')).called(1);
      verify(() => localDataSource.deleteApiaryPermanently('server-1')).called(1);
    });
  });


  group('ApiaryRepositoryImpl - Offline operations', () {
    setUp(() {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
    });

    test('offline create does NOT call remote API and saves to SQLite as pendingCreate', () async {
      when(() => localDataSource.insertApiary(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as Apiary);

      final result = await repository.createApiary(
        name: 'Offline Apiary',
        description: 'Local desc',
        location: 'Local loc',
        lat: 50.0,
        lon: 30.0,
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (apiary) {
        expect(apiary.name, 'Offline Apiary');
        expect(apiary.syncStatus, SyncStatus.pendingCreate);
        expect(apiary.localId, isNotNull);
        expect(apiary.id, startsWith('local-'));
      });
      verifyNever(() => remoteDataSource.createApiary(any()));
      verify(() => localDataSource.insertApiary(any())).called(1);
    });

    test('offline getApiaries reads active records from SQLite', () async {
      when(() => localDataSource.getActiveApiaries(page: 1, limit: 20))
          .thenAnswer((_) async => [sampleOfflineApiary]);

      final result = await repository.getApiaries(page: 1, limit: 20);

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (page) {
        expect(page.items.length, 1);
        expect(page.items.first.id, 'local-123');
      });
      verifyNever(() => remoteDataSource.getApiaries(any()));
      verify(() => localDataSource.getActiveApiaries(page: 1, limit: 20)).called(1);
    });

    test('offline getApiary reads record from SQLite', () async {
      when(() => localDataSource.getApiaryById('local-123'))
          .thenAnswer((_) async => sampleOfflineApiary);

      final result = await repository.getApiary('local-123');

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (apiary) {
        expect(apiary.id, 'local-123');
        expect(apiary.name, 'Offline Apiary');
      });
      verifyNever(() => remoteDataSource.getApiary(any()));
    });

    test('offline update modifies SQLite and marks pendingUpdate if previously synced', () async {
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => sampleSyncedApiary);
      when(() => localDataSource.updateApiary(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as Apiary);

      final result = await repository.updateApiary(
        id: 'server-1',
        name: 'Updated Name',
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (apiary) {
        expect(apiary.name, 'Updated Name');
        expect(apiary.syncStatus, SyncStatus.pendingUpdate);
      });
      verifyNever(() => remoteDataSource.updateApiary(any(), any()));
      verify(() => localDataSource.updateApiary(any())).called(1);
    });

    test('offline update keeps pendingCreate if entity was created offline', () async {
      when(() => localDataSource.getApiaryById('local-123'))
          .thenAnswer((_) async => sampleOfflineApiary);
      when(() => localDataSource.updateApiary(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as Apiary);

      final result = await repository.updateApiary(
        id: 'local-123',
        name: 'New Offline Name',
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (apiary) {
        expect(apiary.name, 'New Offline Name');
        expect(apiary.syncStatus, SyncStatus.pendingCreate);
      });
    });

    test('offline delete of unsynced record deletes permanently from SQLite', () async {
      when(() => localDataSource.getApiaryById('local-123'))
          .thenAnswer((_) async => sampleOfflineApiary);
      when(() => localDataSource.deleteApiaryPermanently('local-123'))
          .thenAnswer((_) async {});

      final result = await repository.deleteApiary('local-123');

      expect(result.isRight, isTrue);
      verify(() => localDataSource.deleteApiaryPermanently('local-123')).called(1);
      verifyNever(() => localDataSource.markPendingDelete(any()));
      verifyNever(() => remoteDataSource.deleteApiary(any()));
    });

    test('offline delete of synced record marks pendingDelete in SQLite without deleting', () async {
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => sampleSyncedApiary);
      when(() => localDataSource.markPendingDelete('server-1'))
          .thenAnswer((_) async {});

      final result = await repository.deleteApiary('server-1');

      expect(result.isRight, isTrue);
      verify(() => localDataSource.markPendingDelete('server-1')).called(1);
      verifyNever(() => localDataSource.deleteApiaryPermanently(any()));
      verifyNever(() => remoteDataSource.deleteApiary(any()));
    });

    test(
        'addApiaryImage offline on synced apiary promotes syncStatus to pendingUpdate '
        'so the synchronizer will pick it up', () async {
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => sampleSyncedApiary);
      when(() => localDataSource.updateApiary(any()))
          .thenAnswer((inv) async => inv.positionalArguments[0] as Apiary);

      final result = await repository.addApiaryImage(
        apiaryId: 'server-1',
        mediaId: 'local-media-123',
      );

      expect(result.isRight, isTrue);
      final captured = verify(() => localDataSource.updateApiary(captureAny())).captured;
      final updated = captured.first as Apiary;
      expect(updated.syncStatus, SyncStatus.pendingUpdate,
          reason: 'Adding a photo offline should mark the apiary as pendingUpdate');
      expect(updated.images, contains('local-media-123'));
    });

    test(
        'addApiaryImage offline on pendingCreate apiary keeps syncStatus as pendingCreate',
        () async {
      when(() => localDataSource.getApiaryById('local-123'))
          .thenAnswer((_) async => sampleOfflineApiary);
      when(() => localDataSource.updateApiary(any()))
          .thenAnswer((inv) async => inv.positionalArguments[0] as Apiary);

      final result = await repository.addApiaryImage(
        apiaryId: 'local-123',
        mediaId: 'local-media-456',
      );

      expect(result.isRight, isTrue);
      final captured = verify(() => localDataSource.updateApiary(captureAny())).captured;
      final updated = captured.first as Apiary;
      expect(updated.syncStatus, SyncStatus.pendingCreate,
          reason: 'A pendingCreate apiary should remain pendingCreate after an offline image add');
    });

    test(
        'removeApiaryImage offline on server photo fails because online photos cannot be deleted offline',
        () async {
      final apiaryWithImage = sampleSyncedApiary.copyWith(images: ['existing-img-id']);
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => apiaryWithImage);

      final result = await repository.removeApiaryImage(
        apiaryId: 'server-1',
        mediaId: 'existing-img-id',
      );

      expect(result.isLeft, isTrue);
      verifyNever(() => localDataSource.updateApiary(any()));
    });

    test(
        'removeApiaryImage offline on local-only photo succeeds and removes it',
        () async {
      final apiaryWithImage = sampleSyncedApiary.copyWith(images: ['local-media-123']);
      when(() => localDataSource.getApiaryById('server-1'))
          .thenAnswer((_) async => apiaryWithImage);
      when(() => localDataSource.updateApiary(any()))
          .thenAnswer((inv) async => inv.positionalArguments[0] as Apiary);

      final result = await repository.removeApiaryImage(
        apiaryId: 'server-1',
        mediaId: 'local-media-123',
      );

      expect(result.isRight, isTrue);
      final captured = verify(() => localDataSource.updateApiary(captureAny())).captured;
      final updated = captured.first as Apiary;
      expect(updated.images, isNot(contains('local-media-123')));
    });
  });
}

