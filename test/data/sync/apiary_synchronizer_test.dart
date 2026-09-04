import 'dart:async';

import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';

class MockApiaryLocalDataSource extends Mock implements IApiaryLocalDataSource {}

class MockApiaryRemoteDataSource extends Mock implements IApiaryDataSource {}

class MockMediaRemoteDataSource extends Mock implements IMediaDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockApiaryLocalDataSource localDataSource;
  late MockApiaryRemoteDataSource apiaryRemoteDataSource;
  late MockMediaRemoteDataSource mediaRemoteDataSource;
  late MockNetworkInfo networkInfo;
  late ApiarySynchronizer synchronizer;

  setUpAll(() {
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
    registerFallbackValue(SyncStatus.synced);
  });

  setUp(() {
    localDataSource = MockApiaryLocalDataSource();
    apiaryRemoteDataSource = MockApiaryRemoteDataSource();
    mediaRemoteDataSource = MockMediaRemoteDataSource();
    networkInfo = MockNetworkInfo();
    synchronizer = ApiarySynchronizer(
      localDataSource: localDataSource,
      apiaryRemoteDataSource: apiaryRemoteDataSource,
      mediaRemoteDataSource: mediaRemoteDataSource,
      networkInfo: networkInfo,
    );
  });

  final pendingCreateApiary = Apiary(
    id: 'local-create-1',
    localId: 'local-create-1',
    name: 'New Offline Apiary',
    description: 'Description',
    location: 'Kyiv',
    lat: 50.0,
    lon: 30.0,
    images: const ['local-media-1'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final pendingUpdateApiary = Apiary(
    id: 'server-update-1',
    localId: 'local-update-1',
    serverId: 'server-update-1',
    name: 'Updated Name',
    description: 'Updated Desc',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
    syncStatus: SyncStatus.pendingUpdate,
  );

  final pendingDeleteApiary = Apiary(
    id: 'server-delete-1',
    localId: 'local-delete-1',
    serverId: 'server-delete-1',
    name: 'To Delete',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingDelete,
  );

  final localMedia = LocalMedia(
    localId: 'local-media-1',
    ownerType: 'apiary',
    ownerId: 'local-create-1',
    localFilePath: '/path/photo.jpg',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    syncStatus: SyncStatus.pendingCreate,
    createdAt: DateTime(2026, 1, 1),
  );

  final sampleMediaResponse = MediaResponse(
    id: 'server-media-uuid',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    imageUrl: 'https://example.com/download',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleApiaryResponse = ApiaryResponse(
    id: 'server-created-uuid',
    name: 'New Offline Apiary',
    description: 'Description',
    location: 'Kyiv',
    lat: 50.0,
    lon: 30.0,
    images: const [
      EntityImageResponse(id: 'server-media-uuid', imageUrl: 'https://example.com/download'),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('ApiarySynchronizer', () {
    test('aborts sync when not connected', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('No internet connection'));
      verifyNever(() => localDataSource.getPendingSyncApiaries());
    });

    test('returns clean result when there are no pending apiaries', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries()).thenAnswer((_) async => []);
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isTrue);
      expect(result.totalPending, 0);
      expect(result.syncedCount, 0);
    });

    test('synchronizes pendingCreate: uploads media first, then creates apiary and marks synced', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingCreateApiary]);
      when(() => localDataSource.getLocalMediaForOwner('local-create-1'))
          .thenAnswer((_) async => [localMedia]);
      when(() => mediaRemoteDataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
          )).thenAnswer((_) async => sampleMediaResponse);
      when(() => localDataSource.updateLocalMediaStatus(
            'local-media-1',
            SyncStatus.synced,
            serverId: 'server-media-uuid',
          )).thenAnswer((_) async {});
      when(() => apiaryRemoteDataSource.createApiary(any()))
          .thenAnswer((_) async => sampleApiaryResponse);
      when(() => localDataSource.markSynced(
            localId: 'local-create-1',
            serverId: 'server-created-uuid',
            images: any(named: 'images'),
          )).thenAnswer((_) async {});
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);

      // Verify media was uploaded before creating apiary
      verify(() => mediaRemoteDataSource.uploadMedia(
            filePath: '/path/photo.jpg',
            originalFilename: 'photo.jpg',
            contentType: 'image/jpeg',
          )).called(1);

      // Verify create request passed the server media id
      final captured = verify(() => apiaryRemoteDataSource.createApiary(captureAny())).captured;
      final request = captured.first as ApiaryRequest;
      expect(request.images, contains('server-media-uuid'));

      // Verify local record was marked synced
      verify(() => localDataSource.markSynced(
            localId: 'local-create-1',
            serverId: 'server-created-uuid',
            images: ['server-media-uuid'],
          )).called(1);
    });

    test('synchronizes pendingUpdate: calls updateApiary and marks synced', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingUpdateApiary]);
      when(() => localDataSource.getLocalMediaForOwner('local-update-1'))
          .thenAnswer((_) async => []);
      when(() => apiaryRemoteDataSource.updateApiary('server-update-1', any()))
          .thenAnswer((_) async => sampleApiaryResponse);
      when(() => localDataSource.markSynced(
            localId: 'local-update-1',
            serverId: 'server-created-uuid',
            images: any(named: 'images'),
          )).thenAnswer((_) async {});
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      verify(() => apiaryRemoteDataSource.updateApiary('server-update-1', any())).called(1);
      verify(() => localDataSource.markSynced(
            localId: 'local-update-1',
            serverId: 'server-created-uuid',
            images: any(named: 'images'),
          )).called(1);
    });

    test('synchronizes pendingDelete: calls deleteApiary and removes row only after server confirms', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingDeleteApiary]);
      when(() => apiaryRemoteDataSource.deleteApiary('server-delete-1'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteApiaryPermanently('local-delete-1'))
          .thenAnswer((_) async {});
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      verify(() => apiaryRemoteDataSource.deleteApiary('server-delete-1')).called(1);
      verify(() => localDataSource.deleteApiaryPermanently('local-delete-1')).called(1);
    });

    test('failed sync preserves local SQLite record and pending status for retry', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingCreateApiary]);
      when(() => localDataSource.getLocalMediaForOwner('local-create-1'))
          .thenAnswer((_) async => []);
      when(() => apiaryRemoteDataSource.createApiary(any())).thenThrow(
        const ServerException(statusCode: 500, code: 'internal_error', message: 'DB Error'),
      );
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isFalse);
      expect(result.failedCount, 1);
      expect(result.syncedCount, 0);

      // Verify local record was NEVER marked synced or deleted
      verifyNever(() => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          ));
      verifyNever(() => localDataSource.deleteApiaryPermanently(any()));
    });

    test('does not create apiary or mark synced if media upload fails', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingCreateApiary]);
      when(() => localDataSource.getLocalMediaForOwner('local-create-1'))
          .thenAnswer((_) async => [localMedia]);
      when(() => mediaRemoteDataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
          )).thenThrow(
        const ServerException(statusCode: 500, code: 'upload_failed', message: 'Upload failed'),
      );
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await synchronizer.syncApiaries();

      expect(result.isSuccess, isFalse);
      expect(result.failedCount, 1);

      // Verify apiary was NOT created on backend
      verifyNever(() => apiaryRemoteDataSource.createApiary(any()));
      // Verify local record was NOT marked synced
      verifyNever(() => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
          ));
    });

    test('orphan-media sweep: uploads photo and patches server apiary when owner is synced', () async {
      // Apiary was created online; only a photo was added offline — it stays synced.
      final syncedApiary = Apiary(
        id: 'server-abc',
        localId: 'server-abc',
        serverId: 'server-abc',
        name: 'Online Apiary',
        images: const ['local-media-999'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        syncStatus: SyncStatus.synced,
      );
      final orphanMedia = LocalMedia(
        localId: 'local-media-999',
        ownerType: 'apiary',
        ownerId: 'server-abc',
        localFilePath: '/tmp/offline.jpg',
        originalFilename: 'offline.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 2048,
        syncStatus: SyncStatus.pendingCreate,
        createdAt: DateTime(2026, 1, 2),
      );
      final serverApiaryResponse = ApiaryResponse(
        id: 'server-abc',
        name: 'Online Apiary',
        images: const [
          EntityImageResponse(id: 'uploaded-media-uuid', imageUrl: 'https://example.com/u.jpg'),
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries()).thenAnswer((_) async => []);
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => [orphanMedia]);
      when(() => localDataSource.getApiaryById('server-abc'))
          .thenAnswer((_) async => syncedApiary);
      when(() => mediaRemoteDataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
          )).thenAnswer((_) async => sampleMediaResponse);
      when(() => localDataSource.updateLocalMediaStatus(
            'local-media-999',
            SyncStatus.synced,
            serverId: 'server-media-uuid',
          )).thenAnswer((_) async {});
      when(() => apiaryRemoteDataSource.getApiary('server-abc'))
          .thenAnswer((_) async => serverApiaryResponse);
      when(() => apiaryRemoteDataSource.updateApiary('server-abc', any()))
          .thenAnswer((_) async => serverApiaryResponse);
      when(() => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: any(named: 'serverId'),
            images: any(named: 'images'),
          )).thenAnswer((_) async {});

      final result = await synchronizer.syncApiaries();

      expect(result.syncedCount, 1);
      verify(() => mediaRemoteDataSource.uploadMedia(
            filePath: '/tmp/offline.jpg',
            originalFilename: 'offline.jpg',
            contentType: 'image/jpeg',
          )).called(1);
      verify(() => apiaryRemoteDataSource.updateApiary('server-abc', any())).called(1);
      verify(() => localDataSource.markSynced(
            localId: any(named: 'localId'),
            serverId: 'server-abc',
            images: any(named: 'images'),
          )).called(1);
    });

    test('calls refreshNotifier.notify when items are successfully synced', () async {
      final refreshNotifier = ApiaryListRefreshNotifier();
      final completer = Completer<void>();
      final sub = refreshNotifier.onChanged.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      addTearDown(sub.cancel);
      addTearDown(refreshNotifier.dispose);

      final syncWithNotifier = ApiarySynchronizer(
        localDataSource: localDataSource,
        apiaryRemoteDataSource: apiaryRemoteDataSource,
        mediaRemoteDataSource: mediaRemoteDataSource,
        networkInfo: networkInfo,
        refreshNotifier: refreshNotifier,
      );

      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncApiaries())
          .thenAnswer((_) async => [pendingCreateApiary]);
      when(() => localDataSource.getLocalMediaForOwner('local-create-1'))
          .thenAnswer((_) async => []);
      when(() => apiaryRemoteDataSource.createApiary(any()))
          .thenAnswer((_) async => sampleApiaryResponse);
      when(() => localDataSource.markSynced(
            localId: 'local-create-1',
            serverId: 'server-created-uuid',
            images: any(named: 'images'),
          )).thenAnswer((_) async {});
      when(() => localDataSource.getPendingMedia()).thenAnswer((_) async => []);

      final result = await syncWithNotifier.syncApiaries();
      await completer.future.timeout(const Duration(milliseconds: 200));

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(completer.isCompleted, isTrue);
    });
  });
}
