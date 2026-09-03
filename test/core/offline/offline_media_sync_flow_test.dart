import 'dart:io';

import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/sqlite_offline_mutation_store.dart';
import 'package:beebase/core/offline/sqlite_operation_queue.dart';
import 'package:beebase/core/offline/sync_activity_tracker.dart';
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
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/data/repositories/owner_image_writer.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
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

class MockLocationService extends Mock implements LocationService {}

class MockHiveWriter extends Mock implements IHiveWriter {}

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

      final activity = SyncActivityTracker();
      final apiaryRefreshNotifier = ApiaryListRefreshNotifier(
        syncActivity: activity,
      );
      final hiveRefreshNotifier = HiveListRefreshNotifier(
        syncActivity: activity,
      );
      // Each entity gets two operations synced in this batch (a create and
      // an imageAdd) — asserting exactly one `onChanged` per notifier for
      // the whole batch is what proves the sync-batch coalescing actually
      // works end-to-end: a list screen open during this sync refreshes
      // once when it finishes, not once per operation (see
      // `SyncCoalescedSignal`'s doc for why that used to make its loading
      // indicator flicker).
      var apiaryRefreshCount = 0;
      var hiveRefreshCount = 0;
      apiaryRefreshNotifier.onChanged.listen((_) => apiaryRefreshCount++);
      hiveRefreshNotifier.onChanged.listen((_) => hiveRefreshCount++);

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
      final ownerImageWriter = OwnerImageWriter(
        apiaryWriter: apiaryRepository,
        hiveWriter: hiveRepository,
      );
      final mediaRepository = MediaRepositoryImpl(
        dataSource: mediaDataSource,
        localDataSource: mediaLocalDataSource,
        localMediaStore: localMediaStore,
        connectivity: connectivity,
        operationQueue: queue,
        offlineMutationStore: mutationStore,
        ownerImageWriter: ownerImageWriter,
      );

      final registry = OperationRegistry({
        'apiary': ApiaryOperationHandler(
          dataSource: apiaryDataSource,
          localDataSource: apiaryLocalDataSource,
          refreshNotifier: apiaryRefreshNotifier,
          operationQueue: queue,
          locationService: MockLocationService(),
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
        ),
      });
      final syncEngine = SyncEngineImpl(
        queue: queue,
        registry: registry,
        connectivity: connectivity,
        activity: activity,
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

      final apiaryPhoto =
          (await mediaRepository.attachMedia(
            ownerType: MediaOwnerType.apiary,
            ownerId: apiary.id,
            localFilePath: apiaryPhotoFile.path,
            originalFilename: 'apiary.jpg',
            contentType: 'image/jpeg',
          )).fold(
            (failure) => throw StateError(
              'apiary photo attach failed offline: $failure',
            ),
            (value) => value,
          );

      // Regression coverage for BEEB-27: the cached apiary must immediately
      // reflect the newly attached photo, not just the operation queue —
      // `MediaGalleryCubit.resolveImages` (and therefore what's shown right
      // after the upload) reads exactly this cached entity's `images`.
      final apiaryAfterAttach = await apiaryRepository.getCachedApiary(
        apiary.id,
      );
      expect(apiaryAfterAttach?.images, contains(apiaryPhoto.id));

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

      final hivePhoto =
          (await mediaRepository.attachMedia(
            ownerType: MediaOwnerType.hive,
            ownerId: hive.id,
            localFilePath: hivePhotoFile.path,
            originalFilename: 'hive.jpg',
            contentType: 'image/jpeg',
          )).fold(
            (failure) =>
                throw StateError('hive photo attach failed offline: $failure'),
            (value) => value,
          );

      final hiveAfterAttach = await hiveRepository.getCachedHive(hive.id);
      expect(hiveAfterAttach?.images, contains(hivePhoto.id));

      // Each photo attach queues two operations: the owner-less upload
      // itself, and a separate `imageAdd` (see `ApiaryRepositoryImpl.
      // addApiaryImage`/`HiveRepositoryImpl.addHiveImage`) linking it to the
      // owner once both the upload and the owner itself have synced.
      final queuedBeforeSync = await queue.all();
      expect(queuedBeforeSync, hasLength(6));
      expect(queuedBeforeSync.map((operation) => operation.entityType), [
        'apiary',
        'media',
        'apiary',
        'hive',
        'media',
        'hive',
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

      var uploadCount = 0;
      when(
        () => mediaDataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        uploadCount++;
        return 'srv-media-$uploadCount';
      });

      // Linking now happens through `ApiaryOperationHandler`/
      // `HiveOperationHandler`'s `imageAdd` handling — a fetch of the
      // owner's current state followed by a PUT with the uploaded id folded
      // into its `images` — rather than a direct media-service attach call.
      when(() => apiaryDataSource.getApiary('srv-apiary-1')).thenAnswer(
        (_) async => ApiaryResponse(
          id: 'srv-apiary-1',
          name: 'Test Apiary',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final capturedApiaryImages = <List<String>>[];
      when(
        () => apiaryDataSource.updateApiary('srv-apiary-1', any()),
      ).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[1] as ApiaryRequest;
        capturedApiaryImages.add(request.images ?? const []);
        return ApiaryResponse(
          id: 'srv-apiary-1',
          name: 'Test Apiary',
          images: request.images ?? const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
      });

      when(() => hiveDataSource.getHive('srv-hive-1')).thenAnswer(
        (_) async => HiveResponse(
          id: 'srv-hive-1',
          apiaryId: 'srv-apiary-1',
          name: 'Test Hive',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final capturedHiveImages = <List<String>>[];
      when(() => hiveDataSource.updateHive('srv-hive-1', any())).thenAnswer((
        invocation,
      ) async {
        final request = invocation.positionalArguments[1] as HiveRequest;
        capturedHiveImages.add(request.images ?? const []);
        return HiveResponse(
          id: 'srv-hive-1',
          apiaryId: 'srv-apiary-1',
          name: 'Test Hive',
          images: request.images ?? const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
      });

      await syncEngine.syncNow();
      // `onChanged` is a broadcast stream, so delivery to `.listen()`
      // callbacks is scheduled a microtask after `add()` rather than
      // happening inline — this just lets that scheduled delivery run
      // before asserting on it.
      await Future<void>.delayed(Duration.zero);

      // Both refresh notifiers coalesced their two per-batch notifies (a
      // create and an imageAdd each) into exactly one `onChanged` event,
      // fired only once the whole batch finished.
      expect(apiaryRefreshCount, 1);
      expect(hiveRefreshCount, 1);
      expect(syncEngine.isSyncing.value, isFalse);

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
      expect(capturedApiaryImages, [
        ['srv-media-1'],
      ]);
      expect(capturedHiveImages, [
        ['srv-media-2'],
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
          (await mediaRepository.getMedia(ids: const ['srv-media-1'])).fold(
            (failure) => throw StateError('offline getMedia failed: $failure'),
            (items) => items,
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
  /// still-mounted `MediaGalleryCubit`) used to ask the server about an
  /// owner id it had never heard of and treat the resulting `ServerFailure`
  /// as "no photo" instead of falling back to the perfectly good cached one.
  /// `getMedia` is ids-based now rather than owner-based, so the id
  /// resolution this used to test is `attachMedia`'s job (see
  /// `MediaRepositoryImpl._resolvedOwnerIdIfSynced`) — what's still worth
  /// covering here is the other half: a still-local, not-yet-synced photo id
  /// (exactly what a `MediaGalleryCubit` still has right after this same
  /// window, before its own reload has a resolved id to ask for) must keep
  /// resolving straight from the cache, network untouched, through the
  /// window where the apiary itself has synced but its photo has not yet.
  test('a photo attached offline and still pending its own sync stays '
      'visible via getMedia(ids: [localId]), served from the cache with no '
      'network call, through the window where its owning apiary has synced '
      'but the photo has not yet', () async {
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
    final ownerImageWriter = OwnerImageWriter(
      apiaryWriter: apiaryRepository,
      hiveWriter: MockHiveWriter(),
    );
    final mediaRepository = MediaRepositoryImpl(
      dataSource: mediaDataSource,
      localDataSource: mediaLocalDataSource,
      localMediaStore: localMediaStore,
      connectivity: connectivity,
      operationQueue: queue,
      offlineMutationStore: mutationStore,
      ownerImageWriter: ownerImageWriter,
    );
    final apiaryHandler = ApiaryOperationHandler(
      dataSource: apiaryDataSource,
      localDataSource: apiaryLocalDataSource,
      refreshNotifier: apiaryRefreshNotifier,
      operationQueue: queue,
      locationService: MockLocationService(),
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

    final attachedPhoto =
        (await mediaRepository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: apiary.id,
          localFilePath: photoFile.path,
          originalFilename: 'race.jpg',
          contentType: 'image/jpeg',
        )).fold(
          (failure) =>
              throw StateError('photo attach failed offline: $failure'),
          (value) => value,
        );
    expect(LocalIdGenerator.isLocal(attachedPhoto.id), isTrue);

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
    expect(mediaCreateOp.localEntityId, attachedPhoto.id);

    // A `MediaGalleryCubit` still mounted on the details page it was built
    // on has no resolved server id for this photo yet either — it keeps
    // asking `getMedia` for the same still-local id it has always had. That
    // must still return the photo straight from the cache, without ever
    // touching the network (the server has never heard of a `local-`
    // prefixed id).
    final items = (await mediaRepository.getMedia(ids: [attachedPhoto.id]))
        .fold(
          (failure) => throw StateError(
            'getMedia failed during the sync race: $failure',
          ),
          (value) => value,
        );

    expect(items, hasLength(1));
    expect(items.single.localFilePath, photoFile.path);
    verifyNever(() => mediaDataSource.listMedia(ids: any(named: 'ids')));
  });
}
