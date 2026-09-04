import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveDataSource extends Mock implements IHiveDataSource {}

class MockHiveLocalDataSource extends Mock implements IHiveLocalDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockHiveDataSource remoteDataSource;
  late MockHiveLocalDataSource localDataSource;
  late MockNetworkInfo networkInfo;
  late HiveRepositoryImpl repository;

  final sampleResponse = HiveResponse(
    id: 'server-hive-1',
    apiaryId: 'apiary-server-1',
    name: 'Online Hive',
    notes: 'Description',
    images: const [
      EntityImageResponse(id: 'img-1', imageUrl: 'https://example.com/1.jpg'),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleOfflineHive = Hive(
    id: 'local-hive-123',
    apiaryId: 'apiary-server-1',
    localId: 'local-hive-123',
    apiaryServerId: 'apiary-server-1',
    name: 'Offline Hive',
    notes: 'Local note',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final sampleSyncedHive = Hive(
    id: 'server-hive-1',
    apiaryId: 'apiary-server-1',
    localId: 'server-hive-1',
    serverId: 'server-hive-1',
    apiaryServerId: 'apiary-server-1',
    name: 'Online Hive',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.synced,
  );

  setUpAll(() {
    registerFallbackValue(const HiveRequest(name: 'fallback'));
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(sampleOfflineHive);
  });

  setUp(() {
    remoteDataSource = MockHiveDataSource();
    localDataSource = MockHiveLocalDataSource();
    networkInfo = MockNetworkInfo();
    repository = HiveRepositoryImpl(
      dataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
  });

  group('HiveRepositoryImpl - Online operations', () {
    setUp(() {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    });

    test('online create calls remote API and caches to local SQLite', () async {
      when(
        () => remoteDataSource.createHive(any(), apiaryId: 'apiary-server-1'),
      ).thenAnswer((_) async => sampleResponse);
      when(
        () => localDataSource.saveServerHives(any()),
      ).thenAnswer((_) async {});

      final result = await repository.createHive(
        apiaryId: 'apiary-server-1',
        name: 'Online Hive',
      );

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (hive) {
        expect(hive.id, 'server-hive-1');
        expect(hive.name, 'Online Hive');
      });
      verify(
        () => remoteDataSource.createHive(any(), apiaryId: 'apiary-server-1'),
      ).called(1);
      verify(() => localDataSource.saveServerHives(any())).called(1);
    });

    test(
      'create while online but parent apiary is still local-only stores the hive '
      'offline instead of calling the API',
      () async {
        when(() => localDataSource.insertHive(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Hive,
        );

        final result = await repository.createHive(
          apiaryId: 'local-apiary-999',
          name: 'Hive Under Unsynced Apiary',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (hive) {
          expect(hive.syncStatus, SyncStatus.pendingCreate);
          expect(hive.apiaryLocalId, 'local-apiary-999');
          expect(hive.apiaryServerId, isNull);
        });
        verifyNever(
          () => remoteDataSource.createHive(
            any(),
            apiaryId: any(named: 'apiaryId'),
          ),
        );
        verify(() => localDataSource.insertHive(any())).called(1);
      },
    );

    test(
      'online getHives merges pendingCreate hives for the apiary on page 1',
      () async {
        when(() => remoteDataSource.getHives(any())).thenAnswer(
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
        when(
          () => localDataSource.saveServerHives(any()),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.getPendingSyncHivesForApiary('apiary-server-1'),
        ).thenAnswer((_) async => [sampleOfflineHive]);

        final result = await repository.getHives(
          apiaryId: 'apiary-server-1',
          page: 1,
          limit: 20,
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (page) {
          expect(page.items.length, 2);
          expect(page.items[0].id, 'local-hive-123');
          expect(page.items[1].id, 'server-hive-1');
        });
      },
    );

    test(
      'online getHive returns local pendingUpdate version instead of server version',
      () async {
        final pendingUpdateHive = sampleSyncedHive.copyWith(
          name: 'Locally Edited Name',
          syncStatus: SyncStatus.pendingUpdate,
        );
        when(
          () => localDataSource.getHiveById('server-hive-1'),
        ).thenAnswer((_) async => pendingUpdateHive);

        final result = await repository.getHive('server-hive-1');

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (hive) {
          expect(hive.name, 'Locally Edited Name');
          expect(hive.syncStatus, SyncStatus.pendingUpdate);
        });
        verifyNever(() => remoteDataSource.getHive(any()));
      },
    );

    test(
      'online delete calls remote API and deletes permanently from SQLite',
      () async {
        when(
          () => localDataSource.getHiveById('server-hive-1'),
        ).thenAnswer((_) async => sampleSyncedHive);
        when(
          () => remoteDataSource.deleteHive('server-hive-1'),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.deleteHivePermanently('server-hive-1'),
        ).thenAnswer((_) async {});

        final result = await repository.deleteHive('server-hive-1');

        expect(result.isRight, isTrue);
        verify(() => remoteDataSource.deleteHive('server-hive-1')).called(1);
        verify(
          () => localDataSource.deleteHivePermanently('server-hive-1'),
        ).called(1);
      },
    );
  });

  group('HiveRepositoryImpl - Offline operations', () {
    setUp(() {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
    });

    test(
      'offline create does NOT call remote API and saves to SQLite as pendingCreate',
      () async {
        when(() => localDataSource.insertHive(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Hive,
        );

        final result = await repository.createHive(
          apiaryId: 'apiary-server-1',
          name: 'Offline Hive',
          notes: 'Local note',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (hive) {
          expect(hive.name, 'Offline Hive');
          expect(hive.syncStatus, SyncStatus.pendingCreate);
          expect(hive.localId, isNotNull);
          expect(hive.id, startsWith('local-'));
          expect(hive.apiaryServerId, 'apiary-server-1');
          expect(hive.apiaryLocalId, isNull);
        });
        verifyNever(
          () => remoteDataSource.createHive(
            any(),
            apiaryId: any(named: 'apiaryId'),
          ),
        );
        verify(() => localDataSource.insertHive(any())).called(1);
      },
    );

    test(
      'offline create under an offline-created apiary references it by local id, '
      'not a fake server id',
      () async {
        when(() => localDataSource.insertHive(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Hive,
        );

        final result = await repository.createHive(
          apiaryId: 'local-apiary-1',
          name: 'Hive Under Offline Apiary',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (hive) {
          expect(hive.apiaryLocalId, 'local-apiary-1');
          expect(hive.apiaryServerId, isNull);
          expect(hive.syncStatus, SyncStatus.pendingCreate);
        });
      },
    );

    test(
      'offline getHives reads active records scoped to the apiary from SQLite',
      () async {
        when(
          () => localDataSource.getActiveHivesForApiary(
            apiaryId: 'apiary-server-1',
            page: 1,
            limit: 20,
          ),
        ).thenAnswer((_) async => [sampleOfflineHive]);

        final result = await repository.getHives(
          apiaryId: 'apiary-server-1',
          page: 1,
          limit: 20,
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (page) {
          expect(page.items.length, 1);
          expect(page.items.first.id, 'local-hive-123');
        });
        verifyNever(() => remoteDataSource.getHives(any()));
      },
    );

    test('offline getHive reads record from SQLite', () async {
      when(
        () => localDataSource.getHiveById('local-hive-123'),
      ).thenAnswer((_) async => sampleOfflineHive);

      final result = await repository.getHive('local-hive-123');

      expect(result.isRight, isTrue);
      result.fold((_) => fail('should succeed'), (hive) {
        expect(hive.id, 'local-hive-123');
        expect(hive.name, 'Offline Hive');
      });
      verifyNever(() => remoteDataSource.getHive(any()));
    });

    test(
      'offline update modifies SQLite and marks pendingUpdate if previously synced',
      () async {
        when(
          () => localDataSource.getHiveById('server-hive-1'),
        ).thenAnswer((_) async => sampleSyncedHive);
        when(() => localDataSource.updateHive(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Hive,
        );

        final result = await repository.updateHive(
          id: 'server-hive-1',
          name: 'Updated Name',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (hive) {
          expect(hive.name, 'Updated Name');
          expect(hive.syncStatus, SyncStatus.pendingUpdate);
        });
        verifyNever(() => remoteDataSource.updateHive(any(), any()));
        verify(() => localDataSource.updateHive(any())).called(1);
      },
    );

    test(
      'offline update keeps pendingCreate if entity was created offline',
      () async {
        when(
          () => localDataSource.getHiveById('local-hive-123'),
        ).thenAnswer((_) async => sampleOfflineHive);
        when(() => localDataSource.updateHive(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Hive,
        );

        final result = await repository.updateHive(
          id: 'local-hive-123',
          name: 'New Offline Name',
        );

        expect(result.isRight, isTrue);
        result.fold((_) => fail('should succeed'), (hive) {
          expect(hive.name, 'New Offline Name');
          expect(hive.syncStatus, SyncStatus.pendingCreate);
        });
      },
    );

    test(
      'offline delete of unsynced record deletes permanently from SQLite',
      () async {
        when(
          () => localDataSource.getHiveById('local-hive-123'),
        ).thenAnswer((_) async => sampleOfflineHive);
        when(
          () => localDataSource.deleteHivePermanently('local-hive-123'),
        ).thenAnswer((_) async {});

        final result = await repository.deleteHive('local-hive-123');

        expect(result.isRight, isTrue);
        verify(
          () => localDataSource.deleteHivePermanently('local-hive-123'),
        ).called(1);
        verifyNever(() => localDataSource.markPendingDelete(any()));
        verifyNever(() => remoteDataSource.deleteHive(any()));
      },
    );

    test(
      'offline delete of synced record marks pendingDelete in SQLite without deleting',
      () async {
        when(
          () => localDataSource.getHiveById('server-hive-1'),
        ).thenAnswer((_) async => sampleSyncedHive);
        when(
          () => localDataSource.markPendingDelete('server-hive-1'),
        ).thenAnswer((_) async {});

        final result = await repository.deleteHive('server-hive-1');

        expect(result.isRight, isTrue);
        verify(
          () => localDataSource.markPendingDelete('server-hive-1'),
        ).called(1);
        verifyNever(() => localDataSource.deleteHivePermanently(any()));
        verifyNever(() => remoteDataSource.deleteHive(any()));
      },
    );

    test(
      'addHiveImage offline on synced hive promotes syncStatus to pendingUpdate '
      'so the synchronizer will pick it up',
      () async {
        when(
          () => localDataSource.getHiveById('server-hive-1'),
        ).thenAnswer((_) async => sampleSyncedHive);
        when(
          () => localDataSource.updateHive(any()),
        ).thenAnswer((inv) async => inv.positionalArguments[0] as Hive);

        final result = await repository.addHiveImage(
          hiveId: 'server-hive-1',
          mediaId: 'local-media-123',
        );

        expect(result.isRight, isTrue);
        final captured = verify(
          () => localDataSource.updateHive(captureAny()),
        ).captured;
        final updated = captured.first as Hive;
        expect(updated.syncStatus, SyncStatus.pendingUpdate);
        expect(updated.images, contains('local-media-123'));
      },
    );

    test(
      'removeHiveImage offline on server photo fails because online photos cannot be deleted offline',
      () async {
        final hiveWithImage = sampleSyncedHive.copyWith(
          images: ['existing-img-id'],
        );
        when(
          () => localDataSource.getHiveById('server-hive-1'),
        ).thenAnswer((_) async => hiveWithImage);

        final result = await repository.removeHiveImage(
          hiveId: 'server-hive-1',
          mediaId: 'existing-img-id',
        );

        expect(result.isLeft, isTrue);
        verifyNever(() => localDataSource.updateHive(any()));
      },
    );
  });
}
