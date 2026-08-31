import 'dart:io';

import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/sqlite_offline_mutation_store.dart';
import 'package:beebase/core/offline/sqlite_operation_queue.dart';
import 'package:beebase/core/offline/sync_engine_impl.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/data/apiary/apiary_operation_handler.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/sqlite_local_data_source.dart';
import 'package:beebase/data/hive/hive_operation_handler.dart';
import 'package:beebase/data/media/media_operation_handler.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../storage/sqlite_test_helper.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

class MockHiveDataSource extends Mock implements IHiveDataSource {}

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockConnectivityService extends Mock implements IConnectivityService {}

/// End-to-end coverage for the exact chain the offline-photo-sync feature
/// promises: an Apiary and a Hive created offline, each with a photo
/// attached offline, all synced from a single `syncNow()` call once
/// connectivity returns. Every other test in this feature mocks its direct
/// collaborators (`OperationQueue`, `OfflineMutationStore`, ...) — real here
/// on purpose, backed by the actual `sqflite_common_ffi` database and the
/// real `ApiaryOperationHandler`/`HiveOperationHandler`/`MediaOperationHandler`,
/// so a bug in how these pieces actually interact (entity-type string
/// mismatches, a dependency id resolving to the wrong row, a payload key the
/// row mapper silently drops) can't hide behind a mock that just assumes the
/// collaboration is correct.
void main() {
  test(
    'Apiary -> apiary photo -> Hive -> hive photo, all created offline, all sync once online',
    () async {
      final database = await openTestDatabase();
      final changeNotifier = OfflineOperationsChangeNotifier();
      final queue = SqliteOperationQueue(database: database, changeNotifier: changeNotifier);
      final mutationStore = SqliteOfflineMutationStore(database: database, changeNotifier: changeNotifier);
      const localMediaStore = LocalMediaStore();

      final apiaryDataSource = MockApiaryDataSource();
      final hiveDataSource = MockHiveDataSource();
      final mediaDataSource = MockMediaDataSource();
      final connectivity = MockConnectivityService();

      registerFallbackValue(const ApiaryRequest(name: 'fallback'));
      registerFallbackValue(const HiveRequest(name: 'fallback'));
      registerFallbackValue(MediaOwnerType.apiary);

      var online = false;
      when(() => connectivity.isOnline).thenAnswer((_) async => online);

      final apiaryLocalDataSource = SqliteLocalDataSource<List<ApiaryResponse>>(
        database: database,
        key: apiaryCacheKey,
        toJson: (list) => list.map((response) => response.toJson()).toList(),
        fromJson: (json) =>
            (json as List<dynamic>).map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>)).toList(),
      );
      final hiveLocalDataSource = SqliteLocalDataSource<List<HiveResponse>>(
        database: database,
        key: hiveCacheKey,
        toJson: (list) => list.map((response) => response.toJson()).toList(),
        fromJson: (json) =>
            (json as List<dynamic>).map((item) => HiveResponse.fromJson(item as Map<String, dynamic>)).toList(),
      );
      final mediaLocalDataSource = SqliteLocalDataSource<List<MediaResponse>>(
        database: database,
        key: mediaCacheKey,
        toJson: (list) => list.map((response) => response.toJson()).toList(),
        fromJson: (json) =>
            (json as List<dynamic>).map((item) => MediaResponse.fromJson(item as Map<String, dynamic>)).toList(),
      );

      final apiaryRefreshNotifier = ApiaryListRefreshNotifier();
      final hiveRefreshNotifier = HiveListRefreshNotifier();

      final apiaryRepository = ApiaryRepositoryImpl(
        dataSource: apiaryDataSource,
        localDataSource: apiaryLocalDataSource,
        connectivity: connectivity,
        operationQueue: queue,
        offlineMutationStore: mutationStore,
      );
      final hiveRepository = HiveRepositoryImpl(
        dataSource: hiveDataSource,
        localDataSource: hiveLocalDataSource,
        connectivity: connectivity,
        operationQueue: queue,
        offlineMutationStore: mutationStore,
      );
      final mediaRepository = MediaRepositoryImpl(
        dataSource: mediaDataSource,
        localDataSource: mediaLocalDataSource,
        localMediaStore: localMediaStore,
        connectivity: connectivity,
        operationQueue: queue,
        offlineMutationStore: mutationStore,
      );

      final registry = OperationRegistry({
        'apiary': ApiaryOperationHandler(
          dataSource: apiaryDataSource,
          localDataSource: apiaryLocalDataSource,
          refreshNotifier: apiaryRefreshNotifier,
          operationQueue: queue,
        ),
        'hive': HiveOperationHandler(
          dataSource: hiveDataSource,
          localDataSource: hiveLocalDataSource,
          refreshNotifier: hiveRefreshNotifier,
          operationQueue: queue,
        ),
        'media': MediaOperationHandler(
          dataSource: mediaDataSource,
          localDataSource: mediaLocalDataSource,
          localMediaStore: localMediaStore,
          operationQueue: queue,
          apiaryRefreshNotifier: apiaryRefreshNotifier,
          hiveRefreshNotifier: hiveRefreshNotifier,
        ),
      });
      final syncEngine = SyncEngineImpl(queue: queue, registry: registry, connectivity: connectivity);

      final apiaryPhotoFile = File(p.join(Directory.systemTemp.path, 'offline_sync_test_apiary_photo.jpg'));
      final hivePhotoFile = File(p.join(Directory.systemTemp.path, 'offline_sync_test_hive_photo.jpg'));
      await apiaryPhotoFile.writeAsBytes([1, 2, 3, 4]);
      await hivePhotoFile.writeAsBytes([5, 6, 7, 8]);

      // --- Offline: create Apiary, attach its photo, create Hive under it,
      // attach the Hive's photo — in that literal order, exactly the
      // workflow a user follows in the app. ---
      online = false;

      final apiary = (await apiaryRepository.createApiary(name: 'Test Apiary')).fold(
        (failure) => throw StateError('createApiary failed offline: $failure'),
        (value) => value,
      );
      expect(LocalIdGenerator.isLocal(apiary.id), isTrue);

      (await mediaRepository.attachMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: apiary.id,
        localFilePath: apiaryPhotoFile.path,
        originalFilename: 'apiary.jpg',
        contentType: 'image/jpeg',
      )).fold((failure) => throw StateError('apiary photo attach failed offline: $failure'), (_) {});

      final hive = (await hiveRepository.createHive(apiaryId: apiary.id, name: 'Test Hive')).fold(
        (failure) => throw StateError('createHive failed offline: $failure'),
        (value) => value,
      );
      expect(LocalIdGenerator.isLocal(hive.id), isTrue);

      (await mediaRepository.attachMedia(
        ownerType: MediaOwnerType.hive,
        ownerId: hive.id,
        localFilePath: hivePhotoFile.path,
        originalFilename: 'hive.jpg',
        contentType: 'image/jpeg',
      )).fold((failure) => throw StateError('hive photo attach failed offline: $failure'), (_) {});

      final queuedBeforeSync = await queue.all();
      expect(queuedBeforeSync, hasLength(4));
      expect(queuedBeforeSync.map((operation) => operation.entityType), ['apiary', 'media', 'hive', 'media']);

      // --- Online: stub the server responses, capturing exactly which owner
      // id each call actually receives — the whole point of
      // `dependsOnOperationId` chaining is that these must be the real
      // backend ids, never the local placeholders used above. ---
      online = true;
      when(
        () => apiaryDataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer(
        (_) async =>
            ApiaryResponse(id: 'srv-apiary-1', name: 'Test Apiary', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
      );

      String? capturedHiveApiaryId;
      when(
        () => hiveDataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        capturedHiveApiaryId = invocation.namedArguments[#apiaryId] as String;
        return HiveResponse(
          id: 'srv-hive-1',
          apiaryId: capturedHiveApiaryId!,
          name: 'Test Hive',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
      });

      final capturedUploads = <String>[];
      when(
        () => mediaDataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        final ownerType = invocation.namedArguments[#ownerType] as MediaOwnerType;
        final ownerId = invocation.namedArguments[#ownerId] as String;
        capturedUploads.add('$ownerType:$ownerId');
        return MediaResponse(
          id: 'srv-media-${capturedUploads.length}',
          ownerType: ownerType,
          ownerId: ownerId,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 4,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
      });

      await syncEngine.syncNow();

      final queuedAfterSync = await queue.all();
      expect(
        queuedAfterSync.every((operation) => operation.status == OperationStatus.synced),
        isTrue,
        reason: queuedAfterSync
            .map((operation) => '${operation.entityType}: ${operation.status} (${operation.lastError})')
            .join(', '),
      );

      expect(capturedHiveApiaryId, 'srv-apiary-1');
      expect(capturedUploads, ['MediaOwnerType.apiary:srv-apiary-1', 'MediaOwnerType.hive:srv-hive-1']);

      // Both files are expected to already be gone here: `MediaOperationHandler`
      // deletes the local copy once its upload is confirmed synced (matching
      // "removed from the pending upload state only after upload and
      // attachment succeed") — this cleanup is only for the case where an
      // assertion above fails first and sync never reaches that step.
      if (await apiaryPhotoFile.exists()) await apiaryPhotoFile.delete();
      if (await hivePhotoFile.exists()) await hivePhotoFile.delete();
    },
  );
}
