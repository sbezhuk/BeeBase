import 'dart:async';

import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveLocalDataSource extends Mock implements IHiveLocalDataSource {}

class MockApiaryLocalDataSource extends Mock
    implements IApiaryLocalDataSource {}

class MockHiveRemoteDataSource extends Mock implements IHiveDataSource {}

class MockMediaRemoteDataSource extends Mock implements IMediaDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockHiveLocalDataSource localDataSource;
  late MockApiaryLocalDataSource apiaryLocalDataSource;
  late MockHiveRemoteDataSource hiveRemoteDataSource;
  late MockMediaRemoteDataSource mediaRemoteDataSource;
  late MockNetworkInfo networkInfo;
  late HiveSynchronizer synchronizer;

  setUpAll(() {
    registerFallbackValue(const HiveRequest(name: 'fallback'));
    registerFallbackValue(SyncStatus.synced);
  });

  setUp(() {
    localDataSource = MockHiveLocalDataSource();
    apiaryLocalDataSource = MockApiaryLocalDataSource();
    hiveRemoteDataSource = MockHiveRemoteDataSource();
    mediaRemoteDataSource = MockMediaRemoteDataSource();
    networkInfo = MockNetworkInfo();
    synchronizer = HiveSynchronizer(
      localDataSource: localDataSource,
      apiaryLocalDataSource: apiaryLocalDataSource,
      hiveRemoteDataSource: hiveRemoteDataSource,
      mediaRemoteDataSource: mediaRemoteDataSource,
      networkInfo: networkInfo,
    );

    // No orphan media unless a test says otherwise.
    when(
      () => apiaryLocalDataSource.getPendingMedia(),
    ).thenAnswer((_) async => []);
  });

  final syncedParentApiary = Apiary(
    id: 'apiary-server-1',
    localId: 'apiary-local-1',
    serverId: 'apiary-server-1',
    name: 'Synced Apiary',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.synced,
  );

  final pendingParentApiary = Apiary(
    id: 'apiary-local-1',
    localId: 'apiary-local-1',
    name: 'Unsynced Apiary',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  Hive hiveUnderLocalApiary({SyncStatus status = SyncStatus.pendingCreate}) =>
      Hive(
        id: 'local-hive-1',
        apiaryId: 'apiary-local-1',
        localId: 'local-hive-1',
        apiaryLocalId: 'apiary-local-1',
        name: 'Hive Under Offline Apiary',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: status,
      );

  Hive hiveUnderSyncedApiary({SyncStatus status = SyncStatus.pendingCreate}) =>
      Hive(
        id: 'local-hive-2',
        apiaryId: 'apiary-server-1',
        localId: 'local-hive-2',
        serverId: status == SyncStatus.synced ? 'server-hive-2' : null,
        apiaryServerId: 'apiary-server-1',
        name: 'Hive Under Synced Apiary',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        syncStatus: status,
      );

  final createdHiveResponse = HiveResponse(
    id: 'server-hive-1',
    apiaryId: 'apiary-server-1',
    name: 'Hive Under Offline Apiary',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('HiveSynchronizer - basic sync lifecycle', () {
    test('aborts sync when not connected', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await synchronizer.syncHives();

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('No internet connection'));
      verifyNever(() => localDataSource.getPendingSyncHives());
    });

    test('returns clean result when there are no pending hives', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => localDataSource.getPendingSyncHives(),
      ).thenAnswer((_) async => []);

      final result = await synchronizer.syncHives();

      expect(result.isSuccess, isTrue);
      expect(result.totalPending, 0);
      expect(result.syncedCount, 0);
    });

    test(
      'synchronizes a pendingCreate hive whose apiary is already synced',
      () async {
        final hive = hiveUnderSyncedApiary();
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        when(
          () => apiaryLocalDataSource.getLocalMediaForOwner('local-hive-2'),
        ).thenAnswer((_) async => []);
        when(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async => createdHiveResponse);
        when(
          () => localDataSource.markSynced(
            localId: 'local-hive-2',
            serverId: 'server-hive-1',
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});

        final result = await synchronizer.syncHives();

        expect(result.isSuccess, isTrue);
        expect(result.syncedCount, 1);
        expect(result.skippedCount, 0);
        verify(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).called(1);
        // No parent lookup needed — this hive was never tracking a local apiary.
        verifyNever(() => apiaryLocalDataSource.getApiaryById(any()));
      },
    );

    test('synchronizes a pendingUpdate hive', () async {
      final hive = hiveUnderSyncedApiary(
        status: SyncStatus.synced,
      ).copyWith(syncStatus: SyncStatus.pendingUpdate, name: 'Updated Name');
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => localDataSource.getPendingSyncHives(),
      ).thenAnswer((_) async => [hive]);
      when(
        () => apiaryLocalDataSource.getLocalMediaForOwner('local-hive-2'),
      ).thenAnswer((_) async => []);
      when(
        () => hiveRemoteDataSource.updateHive('server-hive-2', any()),
      ).thenAnswer((_) async => createdHiveResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-hive-2',
          serverId: 'server-hive-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await synchronizer.syncHives();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      verify(
        () => hiveRemoteDataSource.updateHive('server-hive-2', any()),
      ).called(1);
    });

    test(
      'synchronizes a pendingDelete hive and removes the local row only after server confirms',
      () async {
        final hive = hiveUnderSyncedApiary(
          status: SyncStatus.synced,
        ).copyWith(syncStatus: SyncStatus.pendingDelete);
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        when(
          () => hiveRemoteDataSource.deleteHive('server-hive-2'),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.deleteHivePermanently('local-hive-2'),
        ).thenAnswer((_) async {});

        final result = await synchronizer.syncHives();

        expect(result.isSuccess, isTrue);
        expect(result.syncedCount, 1);
        verify(
          () => hiveRemoteDataSource.deleteHive('server-hive-2'),
        ).called(1);
        verify(
          () => localDataSource.deleteHivePermanently('local-hive-2'),
        ).called(1);
      },
    );

    test(
      'failed sync preserves local SQLite record and pending status for retry',
      () async {
        final hive = hiveUnderSyncedApiary();
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        when(
          () => apiaryLocalDataSource.getLocalMediaForOwner('local-hive-2'),
        ).thenAnswer((_) async => []);
        when(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: any(named: 'apiaryId'),
          ),
        ).thenThrow(
          const ServerException(
            statusCode: 500,
            code: 'internal_error',
            message: 'DB Error',
          ),
        );

        final result = await synchronizer.syncHives();

        expect(result.isSuccess, isFalse);
        expect(result.failedCount, 1);
        expect(result.syncedCount, 0);
        verifyNever(
          () => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
          ),
        );
        verifyNever(() => localDataSource.deleteHivePermanently(any()));
      },
    );
  });

  group('HiveSynchronizer - Apiary -> Hive dependency (mandatory)', () {
    // Test 1 — Parent First: a hive tracking an unsynced local apiary is
    // never sent to the backend before that apiary resolves.
    test(
      'never calls the Hive API for a hive whose parent apiary has not synced',
      () async {
        final hive = hiveUnderLocalApiary();
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        when(
          () => apiaryLocalDataSource.getApiaryById('apiary-local-1'),
        ).thenAnswer((_) async => pendingParentApiary);

        final result = await synchronizer.syncHives();

        expect(result.skippedCount, 1);
        expect(result.syncedCount, 0);
        expect(result.failedCount, 0);
        verifyNever(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: any(named: 'apiaryId'),
          ),
        );
        verifyNever(
          () => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
          ),
        );
      },
    );

    // Test 2 — Parent Failure: when the parent apiary is still pendingCreate
    // (e.g. its own sync attempt failed this round, so it was never marked
    // synced), the hive is left pending and no Hive API call is made.
    test(
      'leaves the hive pending and makes no API request when the parent apiary sync fails',
      () async {
        final hive = hiveUnderLocalApiary();
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        // Parent apiary is still pendingCreate — its own sync attempt failed
        // (or hasn't run yet) this round.
        when(
          () => apiaryLocalDataSource.getApiaryById('apiary-local-1'),
        ).thenAnswer((_) async => pendingParentApiary);

        final result = await synchronizer.syncHives();

        expect(result.skippedCount, 1);
        verifyNever(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: any(named: 'apiaryId'),
          ),
        );
        verifyNever(() => hiveRemoteDataSource.updateHive(any(), any()));
        verifyNever(() => hiveRemoteDataSource.deleteHive(any()));
      },
    );

    // Test 3 — Parent Success: once the parent apiary has synced (already
    // `synced` with a `serverId` by the time this sync pass runs — the
    // ordering itself is `DataSynchronizer`'s job, see its own test), the
    // hive resolves the real server apiary id and syncs using it.
    test(
      'resolves the parent apiary server id and uses it to sync the hive',
      () async {
        final hive = hiveUnderLocalApiary();
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        when(
          () => apiaryLocalDataSource.getApiaryById('apiary-local-1'),
        ).thenAnswer((_) async => syncedParentApiary);
        when(
          () => localDataSource.resolveApiaryServerId(
            apiaryLocalId: 'apiary-local-1',
            apiaryServerId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async {});
        when(
          () => apiaryLocalDataSource.getLocalMediaForOwner('local-hive-1'),
        ).thenAnswer((_) async => []);
        when(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async => createdHiveResponse);
        when(
          () => localDataSource.markSynced(
            localId: 'local-hive-1',
            serverId: 'server-hive-1',
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});

        final result = await synchronizer.syncHives();

        expect(result.isSuccess, isTrue);
        expect(result.syncedCount, 1);
        expect(result.skippedCount, 0);
        verify(
          () => localDataSource.resolveApiaryServerId(
            apiaryLocalId: 'apiary-local-1',
            apiaryServerId: 'apiary-server-1',
          ),
        ).called(1);
        final captured = verify(
          () => hiveRemoteDataSource.createHive(
            captureAny(),
            apiaryId: 'apiary-server-1',
          ),
        ).captured;
        expect(captured, hasLength(1));
      },
    );

    // Test 4 — Multiple Hives: every hive under the same unsynced apiary is
    // skipped until that apiary resolves, then all sync using the same
    // resolved server id.
    test(
      'all hives under the same apiary sync only after that apiary resolves',
      () async {
        final h1 = hiveUnderLocalApiary().copyWith(
          id: 'local-hive-1',
          localId: 'local-hive-1',
        );
        final h2 = hiveUnderLocalApiary().copyWith(
          id: 'local-hive-2',
          localId: 'local-hive-2',
        );
        final h3 = hiveUnderLocalApiary().copyWith(
          id: 'local-hive-3',
          localId: 'local-hive-3',
        );

        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [h1, h2, h3]);
        when(
          () => apiaryLocalDataSource.getApiaryById('apiary-local-1'),
        ).thenAnswer((_) async => syncedParentApiary);
        when(
          () => localDataSource.resolveApiaryServerId(
            apiaryLocalId: 'apiary-local-1',
            apiaryServerId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async {});
        when(
          () => apiaryLocalDataSource.getLocalMediaForOwner(any()),
        ).thenAnswer((_) async => []);
        when(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async => createdHiveResponse);
        when(
          () => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});

        final result = await synchronizer.syncHives();

        expect(result.syncedCount, 3);
        expect(result.skippedCount, 0);
        verify(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).called(3);
      },
    );

    // Test 5 — Partial Child Failure: one hive failing to sync must not
    // affect its already-successful siblings, and must not be dropped.
    test(
      'a failing hive does not affect already-synced siblings and is not deleted',
      () async {
        final h1 = hiveUnderSyncedApiary().copyWith(id: 'h1', localId: 'h1');
        final h2 = hiveUnderSyncedApiary().copyWith(id: 'h2', localId: 'h2');
        final h3 = hiveUnderSyncedApiary().copyWith(id: 'h3', localId: 'h3');

        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [h1, h2, h3]);
        when(
          () => apiaryLocalDataSource.getLocalMediaForOwner(any()),
        ).thenAnswer((_) async => []);
        when(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async => createdHiveResponse);
        when(
          () => localDataSource.markSynced(
            localId: 'h1',
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.markSynced(
            localId: 'h3',
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});

        // h2 fails specifically when its own local media lookup is invoked by
        // throwing there instead — isolates the failure to h2 only.
        when(() => apiaryLocalDataSource.getLocalMediaForOwner('h2')).thenThrow(
          const ServerException(
            statusCode: 500,
            code: 'internal_error',
            message: 'boom',
          ),
        );

        final result = await synchronizer.syncHives();

        expect(result.syncedCount, 2);
        expect(result.failedCount, 1);
        verify(
          () => localDataSource.markSynced(
            localId: 'h1',
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        ).called(1);
        verify(
          () => localDataSource.markSynced(
            localId: 'h3',
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        ).called(1);
        verifyNever(() => localDataSource.deleteHivePermanently('h2'));
        verifyNever(
          () => localDataSource.markSynced(
            localId: 'h2',
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        );
      },
    );

    // Test 6 — Retry: a previously-failed hive can be retried without
    // re-syncing hives that already succeeded (they're no longer pending,
    // so a real run wouldn't even hand them to `getPendingSyncHives` again —
    // this asserts the synchronizer only ever acts on what it's given).
    test('retrying only re-attempts the hive that previously failed', () async {
      final retriedHive = hiveUnderSyncedApiary();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => localDataSource.getPendingSyncHives(),
      ).thenAnswer((_) async => [retriedHive]);
      when(
        () => apiaryLocalDataSource.getLocalMediaForOwner('local-hive-2'),
      ).thenAnswer((_) async => []);
      when(
        () =>
            hiveRemoteDataSource.createHive(any(), apiaryId: 'apiary-server-1'),
      ).thenAnswer((_) async => createdHiveResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-hive-2',
          serverId: 'server-hive-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await synchronizer.syncHives();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      verify(
        () =>
            hiveRemoteDataSource.createHive(any(), apiaryId: 'apiary-server-1'),
      ).called(1);
    });
  });

  group('HiveSynchronizer - orphan media sweep', () {
    test(
      'uploads pending photo and patches server hive when owner hive is already synced',
      () async {
        final syncedHive = Hive(
          id: 'server-hive-abc',
          apiaryId: 'apiary-server-1',
          localId: 'server-hive-abc',
          serverId: 'server-hive-abc',
          apiaryServerId: 'apiary-server-1',
          name: 'Synced Hive',
          images: const ['local-media-999'],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 2),
          syncStatus: SyncStatus.synced,
        );
        final orphanMedia = LocalMedia(
          localId: 'local-media-999',
          ownerType: 'hive',
          ownerId: 'server-hive-abc',
          localFilePath: '/tmp/offline.jpg',
          originalFilename: 'offline.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          syncStatus: SyncStatus.pendingCreate,
          createdAt: DateTime(2026, 1, 2),
        );
        final sampleMediaResponse = MediaResponse(
          id: 'server-media-uuid',
          originalFilename: 'offline.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          imageUrl: 'https://example.com/download',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final serverHiveResponse = HiveResponse(
          id: 'server-hive-abc',
          apiaryId: 'apiary-server-1',
          name: 'Synced Hive',
          images: const [
            EntityImageResponse(
              id: 'uploaded-media-uuid',
              imageUrl: 'https://example.com/u.jpg',
            ),
          ],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 2),
        );

        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => []);
        when(
          () => apiaryLocalDataSource.getPendingMedia(),
        ).thenAnswer((_) async => [orphanMedia]);
        when(
          () => localDataSource.getHiveById('server-hive-abc'),
        ).thenAnswer((_) async => syncedHive);
        when(
          () => mediaRemoteDataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
          ),
        ).thenAnswer((_) async => sampleMediaResponse);
        when(
          () => apiaryLocalDataSource.updateLocalMediaStatus(
            'local-media-999',
            SyncStatus.synced,
            serverId: 'server-media-uuid',
          ),
        ).thenAnswer((_) async {});
        when(
          () => hiveRemoteDataSource.getHive('server-hive-abc'),
        ).thenAnswer((_) async => serverHiveResponse);
        when(
          () => hiveRemoteDataSource.updateHive('server-hive-abc', any()),
        ).thenAnswer((_) async => serverHiveResponse);
        when(
          () => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});

        final result = await synchronizer.syncHives();

        expect(result.syncedCount, 1);
        verify(
          () => hiveRemoteDataSource.updateHive('server-hive-abc', any()),
        ).called(1);
        verify(
          () => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: 'server-hive-abc',
            images: any(named: 'images'),
          ),
        ).called(1);
      },
    );
  });

  group('HiveSynchronizer - refresh notifications', () {
    test(
      'calls refreshNotifier.notify when items are successfully synced',
      () async {
        final refreshNotifier = HiveListRefreshNotifier();
        final completer = Completer<void>();
        final sub = refreshNotifier.onChanged.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        addTearDown(sub.cancel);
        addTearDown(refreshNotifier.dispose);

        final syncWithNotifier = HiveSynchronizer(
          localDataSource: localDataSource,
          apiaryLocalDataSource: apiaryLocalDataSource,
          hiveRemoteDataSource: hiveRemoteDataSource,
          mediaRemoteDataSource: mediaRemoteDataSource,
          networkInfo: networkInfo,
          refreshNotifier: refreshNotifier,
        );

        final hive = hiveUnderSyncedApiary();
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => localDataSource.getPendingSyncHives(),
        ).thenAnswer((_) async => [hive]);
        when(
          () => apiaryLocalDataSource.getLocalMediaForOwner('local-hive-2'),
        ).thenAnswer((_) async => []);
        when(
          () => hiveRemoteDataSource.createHive(
            any(),
            apiaryId: 'apiary-server-1',
          ),
        ).thenAnswer((_) async => createdHiveResponse);
        when(
          () => localDataSource.markSynced(
            localId: 'local-hive-2',
            serverId: 'server-hive-1',
            images: any(named: 'images'),
          ),
        ).thenAnswer((_) async {});

        final result = await syncWithNotifier.syncHives();
        await completer.future.timeout(const Duration(milliseconds: 200));

        expect(result.isSuccess, isTrue);
        expect(completer.isCompleted, isTrue);
      },
    );
  });
}
