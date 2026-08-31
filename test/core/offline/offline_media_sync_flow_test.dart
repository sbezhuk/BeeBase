import 'dart:io';

import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_result.dart';
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
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../storage/fake_path_provider_platform.dart';
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
      final mediaDocumentsDir = await Directory.systemTemp.createTemp(
        'offline_media_sync_flow_test_documents',
      );
      addTearDown(() => mediaDocumentsDir.delete(recursive: true));
      PathProviderPlatform.instance = FakePathProviderPlatform(
        mediaDocumentsDir.path,
      );

      final database = await openTestDatabase();
      final changeNotifier = OfflineOperationsChangeNotifier();
      final queue = SqliteOperationQueue(
        database: database,
        changeNotifier: changeNotifier,
      );
      final mutationStore = SqliteOfflineMutationStore(
        database: database,
        changeNotifier: changeNotifier,
      );
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
        fromJson: (json) => (json as List<dynamic>)
            .map(
              (item) => ApiaryResponse.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
      final hiveLocalDataSource = SqliteLocalDataSource<List<HiveResponse>>(
        database: database,
        key: hiveCacheKey,
        toJson: (list) => list.map((response) => response.toJson()).toList(),
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => HiveResponse.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
      final mediaLocalDataSource = SqliteLocalDataSource<List<MediaResponse>>(
        database: database,
        key: mediaCacheKey,
        toJson: (list) => list.map((response) => response.toJson()).toList(),
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => MediaResponse.fromJson(item as Map<String, dynamic>))
            .toList(),
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
      final syncEngine = SyncEngineImpl(
        queue: queue,
        registry: registry,
        connectivity: connectivity,
      );

      final apiaryPhotoFile = File(
        p.join(Directory.systemTemp.path, 'offline_sync_test_apiary_photo.jpg'),
      );
      final hivePhotoFile = File(
        p.join(Directory.systemTemp.path, 'offline_sync_test_hive_photo.jpg'),
      );
      await apiaryPhotoFile.writeAsBytes([1, 2, 3, 4]);
      await hivePhotoFile.writeAsBytes([5, 6, 7, 8]);

      // --- Offline: create Apiary, attach its photo, create Hive under it,
      // attach the Hive's photo — in that literal order, exactly the
      // workflow a user follows in the app. ---
      online = false;

      final apiary = (await apiaryRepository.createApiary(name: 'Test Apiary'))
          .fold(
            (failure) =>
                throw StateError('createApiary failed offline: $failure'),
            (value) => value,
          );
      expect(LocalIdGenerator.isLocal(apiary.id), isTrue);

      (await mediaRepository.attachMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: apiary.id,
        localFilePath: apiaryPhotoFile.path,
        originalFilename: 'apiary.jpg',
        contentType: 'image/jpeg',
      )).fold(
        (failure) =>
            throw StateError('apiary photo attach failed offline: $failure'),
        (_) {},
      );

      final hive =
          (await hiveRepository.createHive(
            apiaryId: apiary.id,
            name: 'Test Hive',
          )).fold(
            (failure) =>
                throw StateError('createHive failed offline: $failure'),
            (value) => value,
          );
      expect(LocalIdGenerator.isLocal(hive.id), isTrue);

      (await mediaRepository.attachMedia(
        ownerType: MediaOwnerType.hive,
        ownerId: hive.id,
        localFilePath: hivePhotoFile.path,
        originalFilename: 'hive.jpg',
        contentType: 'image/jpeg',
      )).fold(
        (failure) =>
            throw StateError('hive photo attach failed offline: $failure'),
        (_) {},
      );

      final queuedBeforeSync = await queue.all();
      expect(queuedBeforeSync, hasLength(4));
      expect(queuedBeforeSync.map((operation) => operation.entityType), [
        'apiary',
        'media',
        'hive',
        'media',
      ]);

      // --- Online: stub the server responses, capturing exactly which owner
      // id each call actually receives — the whole point of
      // `dependsOnOperationId` chaining is that these must be the real
      // backend ids, never the local placeholders used above. ---
      online = true;
      when(
        () => apiaryDataSource.createApiary(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => ApiaryResponse(
          id: 'srv-apiary-1',
          name: 'Test Apiary',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
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
        final ownerType =
            invocation.namedArguments[#ownerType] as MediaOwnerType;
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
        queuedAfterSync.every(
          (operation) => operation.status == OperationStatus.synced,
        ),
        isTrue,
        reason: queuedAfterSync
            .map(
              (operation) =>
                  '${operation.entityType}: ${operation.status} (${operation.lastError})',
            )
            .join(', '),
      );

      expect(capturedHiveApiaryId, 'srv-apiary-1');
      expect(capturedUploads, [
        'MediaOwnerType.apiary:srv-apiary-1',
        'MediaOwnerType.hive:srv-hive-1',
      ]);

      // The staging copies are gone — `MediaOperationHandler` adopts
      // (renames) each one onto the deterministic cache path for its real
      // server id rather than deleting it, so the photo stays available
      // offline immediately after syncing instead of needing a redundant
      // re-download the next time it's displayed.
      expect(await apiaryPhotoFile.exists(), isFalse);
      expect(await hivePhotoFile.exists(), isFalse);

      final cachedApiaryPhotoPath = await localMediaStore.pathFor(
        'srv-media-1',
        extension: 'jpg',
      );
      final cachedHivePhotoPath = await localMediaStore.pathFor(
        'srv-media-2',
        extension: 'jpg',
      );
      expect(await File(cachedApiaryPhotoPath).exists(), isTrue);
      expect(await File(cachedApiaryPhotoPath).readAsBytes(), [1, 2, 3, 4]);
      expect(await File(cachedHivePhotoPath).exists(), isTrue);
      expect(await File(cachedHivePhotoPath).readAsBytes(), [5, 6, 7, 8]);

      // --- Offline again: the whole point of adopting rather than deleting
      // the staged file — the cache row itself must also point at the
      // adopted path so a reload after this point (or a fresh app launch)
      // doesn't try to re-download something that's already on disk. ---
      online = false;
      final apiaryPhotos =
          (await mediaRepository.getMedia(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'srv-apiary-1',
            page: 1,
            limit: 20,
          )).fold(
            (failure) => throw StateError('offline getMedia failed: $failure'),
            (page) => page.items,
          );
      expect(apiaryPhotos.single.localFilePath, cachedApiaryPhotoPath);
    },
  );

  /// Regression test for the exact bug reported: a photo attached offline to
  /// an Apiary that was *also* created offline used to vanish the instant
  /// connectivity returned, well before the photo's own sync ever ran —
  /// because the Apiary's `create` operation resolves (and broadcasts a
  /// list-refresh notification) one full step of `syncNow()`'s sequential
  /// sweep before the *dependent* photo `create` operation is even
  /// attempted, and whatever reload that notification triggers (e.g. a
  /// still-mounted `MediaGalleryCubit`, forever bound to the Apiary's old
  /// local id — see `ApiaryDetailsPage`) used to ask the server about an id
  /// it had never heard of and treat the resulting `ServerFailure` as "no
  /// photo" instead of falling back to the perfectly good cached one. This
  /// reproduces that exact window directly, without a full `syncNow()`
  /// sweep, by syncing only the Apiary's own operation and deliberately
  /// leaving its photo's `create` operation untouched.
  test('a photo attached to an apiary created offline stays visible via '
      'getMedia — queried by the original local apiary id, exactly as a '
      'still-mounted MediaGalleryCubit would keep doing — through the window '
      'where the apiary itself has synced but its photo has not yet', () async {
    final mediaDocumentsDir = await Directory.systemTemp.createTemp(
      'offline_media_sync_flow_test_race_documents',
    );
    addTearDown(() => mediaDocumentsDir.delete(recursive: true));
    PathProviderPlatform.instance = FakePathProviderPlatform(
      mediaDocumentsDir.path,
    );

    final database = await openTestDatabase();
    final changeNotifier = OfflineOperationsChangeNotifier();
    final queue = SqliteOperationQueue(
      database: database,
      changeNotifier: changeNotifier,
    );
    final mutationStore = SqliteOfflineMutationStore(
      database: database,
      changeNotifier: changeNotifier,
    );
    const localMediaStore = LocalMediaStore();

    final apiaryDataSource = MockApiaryDataSource();
    final mediaDataSource = MockMediaDataSource();
    final connectivity = MockConnectivityService();

    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
    registerFallbackValue(MediaOwnerType.apiary);
    registerFallbackValue(const PageRequest(page: 1, limit: 20));

    var online = false;
    when(() => connectivity.isOnline).thenAnswer((_) async => online);

    final apiaryLocalDataSource = SqliteLocalDataSource<List<ApiaryResponse>>(
      database: database,
      key: apiaryCacheKey,
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    final mediaLocalDataSource = SqliteLocalDataSource<List<MediaResponse>>(
      database: database,
      key: mediaCacheKey,
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => MediaResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    );

    final apiaryRefreshNotifier = ApiaryListRefreshNotifier();
    addTearDown(apiaryRefreshNotifier.dispose);

    final apiaryRepository = ApiaryRepositoryImpl(
      dataSource: apiaryDataSource,
      localDataSource: apiaryLocalDataSource,
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
    final apiaryHandler = ApiaryOperationHandler(
      dataSource: apiaryDataSource,
      localDataSource: apiaryLocalDataSource,
      refreshNotifier: apiaryRefreshNotifier,
      operationQueue: queue,
    );

    final photoFile = File(
      p.join(Directory.systemTemp.path, 'offline_sync_race_test_photo.jpg'),
    );
    await photoFile.writeAsBytes([9, 9, 9, 9]);
    addTearDown(() async {
      if (await photoFile.exists()) await photoFile.delete();
    });

    // --- Offline: create the apiary, attach a photo to it. ---
    online = false;
    final apiary = (await apiaryRepository.createApiary(name: 'Race Apiary'))
        .fold(
          (failure) =>
              throw StateError('createApiary failed offline: $failure'),
          (value) => value,
        );
    expect(LocalIdGenerator.isLocal(apiary.id), isTrue);

    (await mediaRepository.attachMedia(
      ownerType: MediaOwnerType.apiary,
      ownerId: apiary.id,
      localFilePath: photoFile.path,
      originalFilename: 'race.jpg',
      contentType: 'image/jpeg',
    )).fold(
      (failure) => throw StateError('photo attach failed offline: $failure'),
      (_) {},
    );

    // --- Online, but sync ONLY the apiary's own create operation — the
    // exact mid-`syncNow()` state one step after the apiary resolves and
    // before its dependent photo operation is even attempted. ---
    online = true;
    when(
      () => apiaryDataSource.createApiary(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => ApiaryResponse(
        id: 'srv-apiary-race-1',
        name: 'Race Apiary',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

    final apiaryCreateOp = (await queue.all()).firstWhere(
      (operation) => operation.entityType == 'apiary',
    );
    final apiaryResult = await apiaryHandler.handle(apiaryCreateOp);
    final resolvedApiaryId =
        (apiaryResult as OperationSuccess).resolvedEntityId!;
    await queue.update(
      apiaryCreateOp.copyWith(
        status: OperationStatus.synced,
        resolvedEntityId: resolvedApiaryId,
        updatedAt: DateTime.now(),
      ),
    );

    // The photo's own `create` operation is deliberately left untouched —
    // this is the race window itself.
    final mediaCreateOp = (await queue.all()).firstWhere(
      (operation) => operation.entityType == 'media',
    );
    expect(mediaCreateOp.status, OperationStatus.pending);

    // Only stubbed under the *resolved* id — if `getMedia` mistakenly
    // called the network with the stale local id instead, this mock
    // would throw on the unstubbed call rather than silently succeed.
    when(
      () => mediaDataSource.listMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: resolvedApiaryId,
        request: any(named: 'request'),
      ),
    ).thenAnswer(
      (_) async => PaginatedResponse(
        items: const [],
        pagination: const PaginationMeta(
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 1,
          hasNext: false,
          hasPrevious: false,
        ),
      ),
    );

    // A `MediaGalleryCubit` still mounted on the details page it was built
    // on never learns the apiary's id changed — it keeps asking for the
    // OLD local id for as long as that page stays open. This must still
    // return the photo instead of erroring out.
    final page =
        (await mediaRepository.getMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: apiary.id,
          page: 1,
          limit: 20,
        )).fold(
          (failure) => throw StateError(
            'getMedia failed during the sync race: $failure',
          ),
          (value) => value,
        );

    expect(page.items, hasLength(1));
    expect(page.items.single.localFilePath, photoFile.path);
    verifyNever(
      () => mediaDataSource.listMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: apiary.id,
        request: any(named: 'request'),
      ),
    );
  });
}
