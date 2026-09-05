import 'dart:async';

import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/sync/inspection_synchronizer.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionLocalDataSource extends Mock implements IInspectionLocalDataSource {}

class MockHiveLocalDataSource extends Mock implements IHiveLocalDataSource {}

class MockApiaryLocalDataSource extends Mock implements IApiaryLocalDataSource {}

class MockInspectionRemoteDataSource extends Mock implements IInspectionDataSource {}

class MockMediaRemoteDataSource extends Mock implements IMediaDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockInspectionLocalDataSource localDataSource;
  late MockHiveLocalDataSource hiveLocalDataSource;
  late MockApiaryLocalDataSource apiaryLocalDataSource;
  late MockInspectionRemoteDataSource inspectionRemoteDataSource;
  late MockMediaRemoteDataSource mediaRemoteDataSource;
  late MockNetworkInfo networkInfo;
  late InspectionSynchronizer synchronizer;

  setUpAll(() {
    registerFallbackValue(InspectionRequest(date: DateTime(2026), type: InspectionType.routine, notes: 'fallback'));
    registerFallbackValue(SyncStatus.synced);
  });

  setUp(() {
    localDataSource = MockInspectionLocalDataSource();
    hiveLocalDataSource = MockHiveLocalDataSource();
    apiaryLocalDataSource = MockApiaryLocalDataSource();
    inspectionRemoteDataSource = MockInspectionRemoteDataSource();
    mediaRemoteDataSource = MockMediaRemoteDataSource();
    networkInfo = MockNetworkInfo();
    synchronizer = InspectionSynchronizer(
      localDataSource: localDataSource,
      hiveLocalDataSource: hiveLocalDataSource,
      apiaryLocalDataSource: apiaryLocalDataSource,
      inspectionRemoteDataSource: inspectionRemoteDataSource,
      mediaRemoteDataSource: mediaRemoteDataSource,
      networkInfo: networkInfo,
    );

    // No orphan media unless a test says otherwise.
    when(() => apiaryLocalDataSource.getPendingMedia()).thenAnswer((_) async => []);
    // No pending local photos unless a test says otherwise.
    when(() => apiaryLocalDataSource.getLocalMediaForOwner(any())).thenAnswer((_) async => []);
  });

  final syncedParentHive = Hive(
    id: 'hive-server-1',
    apiaryId: 'apiary-server-1',
    localId: 'hive-local-1',
    serverId: 'hive-server-1',
    apiaryServerId: 'apiary-server-1',
    name: 'Synced Hive',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.synced,
  );

  final pendingParentHive = Hive(
    id: 'hive-local-1',
    apiaryId: 'apiary-server-1',
    localId: 'hive-local-1',
    apiaryServerId: 'apiary-server-1',
    name: 'Unsynced Hive',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  Inspection inspectionUnderLocalHive({SyncStatus status = SyncStatus.pendingCreate}) => Inspection(
    id: 'local-inspection-1',
    hiveId: 'hive-local-1',
    localId: 'local-inspection-1',
    hiveLocalId: 'hive-local-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'Under offline hive',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: status,
  );

  Inspection inspectionUnderSyncedHive({SyncStatus status = SyncStatus.pendingCreate}) => Inspection(
    id: 'local-inspection-2',
    hiveId: 'hive-server-1',
    localId: 'local-inspection-2',
    serverId: status == SyncStatus.synced ? 'server-inspection-2' : null,
    hiveServerId: 'hive-server-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.health,
    notes: 'Under synced hive',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: status,
  );

  final createdInspectionResponse = InspectionResponse(
    id: 'server-inspection-1',
    hiveId: 'hive-server-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'Under offline hive',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('InspectionSynchronizer - basic sync lifecycle', () {
    test('aborts sync when not connected', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isFalse);
      expect(result.errors, contains('No internet connection'));
      verifyNever(() => localDataSource.getPendingSyncInspections());
    });

    test('returns clean result when there are no pending inspections', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => []);

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isTrue);
      expect(result.totalPending, 0);
      expect(result.syncedCount, 0);
    });

    test('synchronizes a pendingCreate inspection whose hive is already synced', () async {
      final inspection = inspectionUnderSyncedHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(
        () => inspectionRemoteDataSource.createInspection('hive-server-1', any()),
      ).thenAnswer((_) async => createdInspectionResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-inspection-2',
          serverId: 'server-inspection-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(result.skippedCount, 0);
      verify(() => inspectionRemoteDataSource.createInspection('hive-server-1', any())).called(1);
      // No parent lookup needed — this inspection was never tracking a
      // local hive.
      verifyNever(() => hiveLocalDataSource.getHiveById(any()));
    });

    test('synchronizes a pendingUpdate inspection', () async {
      final inspection = inspectionUnderSyncedHive(
        status: SyncStatus.synced,
      ).copyWith(syncStatus: SyncStatus.pendingUpdate, notes: 'Updated notes');
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(
        () => inspectionRemoteDataSource.updateInspection('hive-server-1', 'server-inspection-2', any()),
      ).thenAnswer((_) async => createdInspectionResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-inspection-2',
          serverId: 'server-inspection-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      verify(() => inspectionRemoteDataSource.updateInspection('hive-server-1', 'server-inspection-2', any())).called(1);
    });

    test('synchronizes a pendingDelete inspection and removes the local row only after server confirms', () async {
      final inspection = inspectionUnderSyncedHive(status: SyncStatus.synced).copyWith(syncStatus: SyncStatus.pendingDelete);
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(() => inspectionRemoteDataSource.deleteInspection('hive-server-1', 'server-inspection-2')).thenAnswer((_) async {});
      when(() => localDataSource.deleteInspectionPermanently('local-inspection-2')).thenAnswer((_) async {});

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      verify(() => inspectionRemoteDataSource.deleteInspection('hive-server-1', 'server-inspection-2')).called(1);
      verify(() => localDataSource.deleteInspectionPermanently('local-inspection-2')).called(1);
    });

    test('failed sync preserves local SQLite record and pending status for retry', () async {
      final inspection = inspectionUnderSyncedHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(
        () => inspectionRemoteDataSource.createInspection(any(), any()),
      ).thenThrow(const ServerException(statusCode: 500, code: 'internal_error', message: 'DB Error'));

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isFalse);
      expect(result.failedCount, 1);
      expect(result.syncedCount, 0);
      verifyNever(
        () => localDataSource.markSynced(
          localId: any(named: 'localId'),
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      );
      verifyNever(() => localDataSource.deleteInspectionPermanently(any()));
    });

    test('retrying after a failed sync successfully synchronizes the inspection '
        'without losing or duplicating it', () async {
      final inspection = inspectionUnderSyncedHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(
        () => inspectionRemoteDataSource.createInspection('hive-server-1', any()),
      ).thenThrow(const ServerException(statusCode: 500, code: 'internal_error', message: 'DB Error'));

      final failedResult = await synchronizer.syncInspections();
      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.failedCount, 1);

      // The exact same still-pending inspection is handed back on retry —
      // nothing was lost or duplicated by the failed attempt.
      when(
        () => inspectionRemoteDataSource.createInspection('hive-server-1', any()),
      ).thenAnswer((_) async => createdInspectionResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-inspection-2',
          serverId: 'server-inspection-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final retryResult = await synchronizer.syncInspections();

      expect(retryResult.isSuccess, isTrue);
      expect(retryResult.syncedCount, 1);
      expect(retryResult.failedCount, 0);
      verify(() => inspectionRemoteDataSource.createInspection('hive-server-1', any())).called(2);
      verify(
        () => localDataSource.markSynced(
          localId: 'local-inspection-2',
          serverId: 'server-inspection-1',
          images: any(named: 'images'),
        ),
      ).called(1);
    });
  });

  group('InspectionSynchronizer - Hive -> Inspection dependency (mandatory)', () {
    test('never calls the Inspection API for an inspection whose parent hive has not synced', () async {
      final inspection = inspectionUnderLocalHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(() => hiveLocalDataSource.getHiveById('hive-local-1')).thenAnswer((_) async => pendingParentHive);

      final result = await synchronizer.syncInspections();

      expect(result.skippedCount, 1);
      expect(result.syncedCount, 0);
      expect(result.failedCount, 0);
      verifyNever(() => inspectionRemoteDataSource.createInspection(any(), any()));
      verifyNever(
        () => localDataSource.markSynced(
          localId: any(named: 'localId'),
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      );
    });

    test('leaves the inspection pending and makes no API request when the parent hive sync fails', () async {
      final inspection = inspectionUnderLocalHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(() => hiveLocalDataSource.getHiveById('hive-local-1')).thenAnswer((_) async => pendingParentHive);

      final result = await synchronizer.syncInspections();

      expect(result.skippedCount, 1);
      verifyNever(() => inspectionRemoteDataSource.createInspection(any(), any()));
      verifyNever(() => inspectionRemoteDataSource.updateInspection(any(), any(), any()));
      verifyNever(() => inspectionRemoteDataSource.deleteInspection(any(), any()));
    });

    test('resolves the parent hive server id and uses it to sync the inspection', () async {
      final inspection = inspectionUnderLocalHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(() => hiveLocalDataSource.getHiveById('hive-local-1')).thenAnswer((_) async => syncedParentHive);
      when(
        () => localDataSource.resolveHiveServerId(hiveLocalId: 'hive-local-1', hiveServerId: 'hive-server-1'),
      ).thenAnswer((_) async {});
      when(
        () => inspectionRemoteDataSource.createInspection('hive-server-1', any()),
      ).thenAnswer((_) async => createdInspectionResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-inspection-1',
          serverId: 'server-inspection-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await synchronizer.syncInspections();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(result.skippedCount, 0);
      verify(() => localDataSource.resolveHiveServerId(hiveLocalId: 'hive-local-1', hiveServerId: 'hive-server-1')).called(1);
    });

    test('a failing inspection does not affect already-synced siblings and is not deleted', () async {
      final i1 = inspectionUnderSyncedHive().copyWith(id: 'i1', localId: 'i1');
      final i2 = inspectionUnderSyncedHive().copyWith(id: 'i2', localId: 'i2');
      final i3 = inspectionUnderSyncedHive().copyWith(id: 'i3', localId: 'i3');

      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [i1, i2, i3]);
      when(() => inspectionRemoteDataSource.createInspection('hive-server-1', any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[1] as InspectionRequest;
        if (request.notes == 'boom') {
          throw const ServerException(statusCode: 500, code: 'internal_error', message: 'boom');
        }
        return createdInspectionResponse;
      });
      when(
        () => localDataSource.markSynced(
          localId: any(named: 'localId'),
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      // i2 fails specifically — give it distinguishing notes so the mocked
      // remote call above throws only for it.
      final failingI2 = i2.copyWith(notes: 'boom');

      final resultPending = [i1, failingI2, i3];
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => resultPending);

      final result = await synchronizer.syncInspections();

      expect(result.syncedCount, 2);
      expect(result.failedCount, 1);
      verify(
        () => localDataSource.markSynced(
          localId: 'i1',
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      ).called(1);
      verify(
        () => localDataSource.markSynced(
          localId: 'i3',
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      ).called(1);
      verifyNever(() => localDataSource.deleteInspectionPermanently('i2'));
      verifyNever(
        () => localDataSource.markSynced(
          localId: 'i2',
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      );
    });
  });

  group('InspectionSynchronizer - orphan media sweep', () {
    test('uploads pending photo and patches server inspection when owner inspection is already synced', () async {
      final syncedInspection = Inspection(
        id: 'server-inspection-abc',
        hiveId: 'hive-server-1',
        localId: 'server-inspection-abc',
        serverId: 'server-inspection-abc',
        hiveServerId: 'hive-server-1',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'Synced inspection',
        images: const ['local-media-999'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        syncStatus: SyncStatus.synced,
      );
      final orphanMedia = LocalMedia(
        localId: 'local-media-999',
        ownerType: 'inspection',
        ownerId: 'server-inspection-abc',
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
      final serverInspectionResponse = InspectionResponse(
        id: 'server-inspection-abc',
        hiveId: 'hive-server-1',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'Synced inspection',
        images: const [EntityImageResponse(id: 'uploaded-media-uuid', imageUrl: 'https://example.com/u.jpg')],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => []);
      when(() => apiaryLocalDataSource.getPendingMedia()).thenAnswer((_) async => [orphanMedia]);
      when(() => localDataSource.getInspectionById('server-inspection-abc')).thenAnswer((_) async => syncedInspection);
      when(
        () => mediaRemoteDataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
        ),
      ).thenAnswer((_) async => sampleMediaResponse);
      when(
        () => apiaryLocalDataSource.updateLocalMediaStatus('local-media-999', SyncStatus.synced, serverId: 'server-media-uuid'),
      ).thenAnswer((_) async {});
      when(
        () => inspectionRemoteDataSource.getInspection('hive-server-1', 'server-inspection-abc'),
      ).thenAnswer((_) async => serverInspectionResponse);
      when(
        () => inspectionRemoteDataSource.updateInspection('hive-server-1', 'server-inspection-abc', any()),
      ).thenAnswer((_) async => serverInspectionResponse);
      when(
        () => localDataSource.markSynced(
          localId: any(named: 'localId'),
          serverId: any(named: 'serverId'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await synchronizer.syncInspections();

      expect(result.syncedCount, 1);
      verify(() => inspectionRemoteDataSource.updateInspection('hive-server-1', 'server-inspection-abc', any())).called(1);
      verify(
        () => localDataSource.markSynced(
          localId: any(named: 'localId'),
          serverId: 'server-inspection-abc',
          images: any(named: 'images'),
        ),
      ).called(1);
    });
  });

  group('InspectionSynchronizer - refresh notifications', () {
    test('calls refreshNotifier.notify when items are successfully synced', () async {
      final refreshNotifier = InspectionListRefreshNotifier();
      final completer = Completer<void>();
      final sub = refreshNotifier.onChanged.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      addTearDown(sub.cancel);
      addTearDown(refreshNotifier.dispose);

      final syncWithNotifier = InspectionSynchronizer(
        localDataSource: localDataSource,
        hiveLocalDataSource: hiveLocalDataSource,
        apiaryLocalDataSource: apiaryLocalDataSource,
        inspectionRemoteDataSource: inspectionRemoteDataSource,
        mediaRemoteDataSource: mediaRemoteDataSource,
        networkInfo: networkInfo,
        refreshNotifier: refreshNotifier,
      );

      final inspection = inspectionUnderSyncedHive();
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(() => localDataSource.getPendingSyncInspections()).thenAnswer((_) async => [inspection]);
      when(
        () => inspectionRemoteDataSource.createInspection('hive-server-1', any()),
      ).thenAnswer((_) async => createdInspectionResponse);
      when(
        () => localDataSource.markSynced(
          localId: 'local-inspection-2',
          serverId: 'server-inspection-1',
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) async {});

      final result = await syncWithNotifier.syncInspections();
      await completer.future.timeout(const Duration(milliseconds: 200));

      expect(result.isSuccess, isTrue);
      expect(completer.isCompleted, isTrue);
    });
  });
}
