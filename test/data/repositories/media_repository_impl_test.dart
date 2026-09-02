import 'dart:async';
import 'dart:io';

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
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockMediaLocalDataSource extends Mock
    implements LocalDataSource<List<MediaResponse>> {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

class MockOwnerImageWriter extends Mock implements IOwnerImageWriter {}

void main() {
  late MockMediaDataSource dataSource;
  late MockMediaLocalDataSource localDataSource;
  late MockLocalMediaStore localMediaStore;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late MockOfflineMutationStore offlineMutationStore;
  late MockOwnerImageWriter ownerImageWriter;
  late MediaRepositoryImpl repository;
  late Directory tempDir;
  late File localFile;

  final mediaResponse = MediaResponse(
    id: 'media-1',
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(MediaOwnerType.apiary);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<MediaResponse>[]);
    registerFallbackValue(
      OfflineOperation(
        id: 'fallback-op',
        entityType: 'media',
        operationType: OperationType.create,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    List<MediaResponse> mutateFallback(List<MediaResponse>? current) =>
        <MediaResponse>[];
    Object? toJsonFallback(List<MediaResponse> value) => null;
    List<MediaResponse> fromJsonFallback(Object? json) => <MediaResponse>[];
    registerFallbackValue(mutateFallback);
    registerFallbackValue(toJsonFallback);
    registerFallbackValue(fromJsonFallback);
  });

  setUp(() async {
    dataSource = MockMediaDataSource();
    localDataSource = MockMediaLocalDataSource();
    localMediaStore = MockLocalMediaStore();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    offlineMutationStore = MockOfflineMutationStore();
    ownerImageWriter = MockOwnerImageWriter();
    repository = MediaRepositoryImpl(
      dataSource: dataSource,
      localDataSource: localDataSource,
      localMediaStore: localMediaStore,
      connectivity: connectivity,
      operationQueue: operationQueue,
      offlineMutationStore: offlineMutationStore,
      ownerImageWriter: ownerImageWriter,
    );

    tempDir = await Directory.systemTemp.createTemp(
      'media_repository_impl_test',
    );
    localFile = File('${tempDir.path}/photo.jpg');
    await localFile.writeAsBytes([1, 2, 3, 4]);

    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => localDataSource.read()).thenAnswer((_) async => null);
    when(() => localDataSource.write(any())).thenAnswer((_) async {});
    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update =
          invocation.positionalArguments.single
              as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      await update(await localDataSource.read());
    });
    when(() => operationQueue.all()).thenAnswer((_) async => []);
    when(() => operationQueue.remove(any())).thenAnswer((_) async {});
    when(() => operationQueue.enqueue(any())).thenAnswer((_) async {});
    when(() => localMediaStore.delete(any())).thenAnswer((_) async {});
    when(
      () => offlineMutationStore.saveWithPendingOperation<List<MediaResponse>>(
        cacheKey: any(named: 'cacheKey'),
        mutate: any(named: 'mutate'),
        toJson: any(named: 'toJson'),
        fromJson: any(named: 'fromJson'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => ownerImageWriter.addImage(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
        mediaId: any(named: 'mediaId'),
      ),
    ).thenAnswer((_) async => const Right(MediaSyncStatus.synced));
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('getMedia', () {
    test('returns Right([]) immediately for an empty ids list, no cache or '
        'network touched', () async {
      final result = await repository.getMedia(ids: const []);

      result.fold(
        (_) => fail('expected Right'),
        (items) => expect(items, isEmpty),
      );
      verifyNever(
        () => dataSource.listMedia(ids: any(named: 'ids')),
      );
    });

    test(
      'fetches the real ids from the network, in request order, and merges the response into the cache',
      () async {
        final second = MediaResponse(
          id: 'media-2',
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          originalFilename: 'other.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 512,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          () => dataSource.listMedia(ids: ['media-2', 'media-1']),
        ).thenAnswer((_) async => [mediaResponse, second]);

        final result = await repository.getMedia(
          ids: ['media-2', 'media-1'],
        );

        result.fold((_) => fail('expected Right'), (items) {
          expect(items.map((attachment) => attachment.id), [
            'media-2',
            'media-1',
          ]);
        });
      },
    );

    test(
      'maps a thrown exception to a Failure when nothing is cached',
      () async {
        when(
          () => dataSource.listMedia(ids: any(named: 'ids')),
        ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

        final result = await repository.getMedia(ids: ['media-1']);

        expect(result, isA<Left<Failure, dynamic>>());
      },
    );

    test('does not fall back to the cache on a real server failure', () async {
      when(
        () => dataSource.listMedia(ids: any(named: 'ids')),
      ).thenThrow(
        const ServerException(
          statusCode: 403,
          code: 'forbidden',
          message: 'not allowed',
        ),
      );

      final result = await repository.getMedia(ids: ['media-1']);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test(
      'reads straight from the cache, filtered and ordered to the requested ids, when offline',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(() => localDataSource.read()).thenAnswer(
          (_) async => [
            mediaResponse,
            MediaResponse(
              id: 'media-2',
              ownerType: MediaOwnerType.hive,
              ownerId: 'hive-1',
              originalFilename: 'o.jpg',
              contentType: 'image/jpeg',
              sizeBytes: 1,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
        );

        final result = await repository.getMedia(ids: ['media-1']);

        result.fold(
          (_) => fail('expected Right'),
          (items) => expect(items.map((a) => a.id), ['media-1']),
        );
        verifyNever(() => dataSource.listMedia(ids: any(named: 'ids')));
      },
    );

    test('fails when offline with nothing cached for the requested ids', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.getMedia(ids: ['media-1']);

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('never calls the network for a still-local, unsynced id, even '
        'while online — the server has never heard of it, so a photo already '
        'cached for it (and pending its own sync) must keep showing from '
        'cache instead of the request failing outright', () async {
      final localPlaceholder = mediaResponse.copyWithLocalPath(
        id: 'local-media-1',
        localFilePath: localFile.path,
      );
      when(
        () => localDataSource.read(),
      ).thenAnswer((_) async => [localPlaceholder]);
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'media-op-1',
            entityType: 'media',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-media-1',
          ),
        ],
      );

      final result = await repository.getMedia(ids: ['local-media-1']);

      result.fold(
        (_) => fail('expected Right'),
        (items) => expect(items.single.id, 'local-media-1'),
      );
      verifyNever(() => dataSource.listMedia(ids: any(named: 'ids')));
    });

    test('a request made only of still-local ids with nothing cached yet is '
        'a legitimate empty result, not a failure — unlike the generic '
        'offline fallback, there is no "we don\'t know" case here', () async {
      final result = await repository.getMedia(ids: ['local-media-1']);

      result.fold(
        (_) => fail('expected Right'),
        (items) => expect(items, isEmpty),
      );
    });

    test('splits a mixed request: still-local ids are served from the cache '
        'only, real ids are fetched from the network, and both halves come '
        'back together in the original request order', () async {
      final localPlaceholder = mediaResponse.copyWithLocalPath(
        id: 'local-media-1',
        localFilePath: localFile.path,
      );
      when(
        () => localDataSource.read(),
      ).thenAnswer((_) async => [localPlaceholder]);
      when(() => operationQueue.all()).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 'media-op-1',
            entityType: 'media',
            operationType: OperationType.create,
            payload: const {},
            status: OperationStatus.pending,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            localEntityId: 'local-media-1',
          ),
        ],
      );
      final second = MediaResponse(
        id: 'media-2',
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        originalFilename: 'other.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 512,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => dataSource.listMedia(ids: ['media-2']),
      ).thenAnswer((_) async => [second]);

      final result = await repository.getMedia(
        ids: ['local-media-1', 'media-2'],
      );

      result.fold(
        (_) => fail('expected Right'),
        (items) => expect(items.map((a) => a.id), [
          'local-media-1',
          'media-2',
        ]),
      );
      verify(() => dataSource.listMedia(ids: ['media-2'])).called(1);
    });
  });

  group('attachMedia', () {
    test(
      'uploads then links to the owner via IOwnerImageWriter, returning the mapped attachment and preserving the local file path in the cache entry',
      () async {
        when(
          () => dataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            idempotencyKey: any(named: 'idempotencyKey'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => 'media-1');

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        result.fold((_) => fail('expected Right'), (attachment) {
          expect(attachment.id, 'media-1');
          expect(attachment.localFilePath, localFile.path);
          expect(attachment.syncStatus, MediaSyncStatus.synced);
        });
        verify(
          () => ownerImageWriter.addImage(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'apiary-1',
            mediaId: 'media-1',
          ),
        ).called(1);
        verifyNever(
          () => offlineMutationStore
              .saveWithPendingOperation<List<MediaResponse>>(
                cacheKey: any(named: 'cacheKey'),
                mutate: any(named: 'mutate'),
                toJson: any(named: 'toJson'),
                fromJson: any(named: 'fromJson'),
                operation: any(named: 'operation'),
              ),
        );
      },
    );

    test(
      'a server failure (e.g. unsupported file type) surfaces immediately without queuing anything',
      () async {
        when(
          () => dataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            idempotencyKey: any(named: 'idempotencyKey'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(
          const ServerException(
            statusCode: 415,
            code: 'unsupported_file_type',
            message: 'bad type',
          ),
        );

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        result.fold(
          (failure) => expect(
            failure,
            isA<ServerFailure>().having(
              (f) => f.code,
              'code',
              'unsupported_file_type',
            ),
          ),
          (_) => fail('expected Left'),
        );
        verifyNever(
          () => offlineMutationStore
              .saveWithPendingOperation<List<MediaResponse>>(
                cacheKey: any(named: 'cacheKey'),
                mutate: any(named: 'mutate'),
                toJson: any(named: 'toJson'),
                fromJson: any(named: 'fromJson'),
                operation: any(named: 'operation'),
              ),
        );
      },
    );

    test(
      'falls back to an offline attach when the network call fails with a connectivity error',
      () async {
        when(
          () => dataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            idempotencyKey: any(named: 'idempotencyKey'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(const InternalException(ErrorTextRaw('no connection')));
        when(
          () => ownerImageWriter.addImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            mediaId: any(named: 'mediaId'),
          ),
        ).thenAnswer((_) async => const Right(MediaSyncStatus.pending));

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        result.fold(
          (_) => fail('expected Right'),
          (attachment) =>
              expect(attachment.syncStatus, MediaSyncStatus.pending),
        );
        verify(
          () => offlineMutationStore
              .saveWithPendingOperation<List<MediaResponse>>(
                cacheKey: any(named: 'cacheKey'),
                mutate: any(named: 'mutate'),
                toJson: any(named: 'toJson'),
                fromJson: any(named: 'fromJson'),
                operation: any(named: 'operation'),
              ),
        ).called(1);
      },
    );

    test(
      'attaches locally and enqueues a pending operation atomically when offline',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(
          () => ownerImageWriter.addImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            mediaId: any(named: 'mediaId'),
          ),
        ).thenAnswer((_) async => const Right(MediaSyncStatus.pending));

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        result.fold((_) => fail('expected Right'), (attachment) {
          expect(attachment.syncStatus, MediaSyncStatus.pending);
          expect(LocalIdGenerator.isLocal(attachment.id), isTrue);
        });
        verifyNever(
          () => dataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
          ),
        );
        final captured = verify(
          () => offlineMutationStore
              .saveWithPendingOperation<List<MediaResponse>>(
                cacheKey: any(named: 'cacheKey'),
                mutate: any(named: 'mutate'),
                toJson: any(named: 'toJson'),
                fromJson: any(named: 'fromJson'),
                operation: captureAny(named: 'operation'),
              ),
        ).captured;
        final operation = captured.single as OfflineOperation;
        expect(operation.entityType, 'media');
        expect(operation.operationType, OperationType.create);
        // The upload operation itself is owner-less (uploading bytes never
        // needed an owner to exist — see MediaRepositoryImpl._attachOffline) —
        // linking to the owner is ownerImageWriter's separate job, verified
        // below.
        expect(operation.payload.containsKey('owner_type'), isFalse);
        expect(operation.payload.containsKey('owner_id'), isFalse);
        expect(operation.dependsOnOperationId, isNull);
        verify(
          () => ownerImageWriter.addImage(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'apiary-1',
            mediaId: any(named: 'mediaId'),
          ),
        ).called(1);
      },
    );

    test('the queued payload carries a UUID-formatted idempotency key, distinct '
        'from the local-prefixed operation id — MediaOperationHandler sends it '
        'as the media_id form field on upload, and unlike Apiary/Hive (where '
        'the idempotency key only ever travels as an opaque header) a '
        '`local-`-prefixed value there is rejected by the server on every '
        'sync retry, even though it is perfectly fine as this operation\'s own '
        'queue-row id', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      const uuidPattern =
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

      await repository.attachMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        localFilePath: localFile.path,
        originalFilename: 'photo.jpg',
        contentType: 'image/jpeg',
      );

      final captured = verify(
        () =>
            offlineMutationStore.saveWithPendingOperation<List<MediaResponse>>(
              cacheKey: any(named: 'cacheKey'),
              mutate: any(named: 'mutate'),
              toJson: any(named: 'toJson'),
              fromJson: any(named: 'fromJson'),
              operation: captureAny(named: 'operation'),
            ),
      ).captured;
      final operation = captured.single as OfflineOperation;
      final idempotencyKey = operation.payload['idempotency_key'] as String;
      expect(idempotencyKey, matches(RegExp(uuidPattern)));
      expect(LocalIdGenerator.isLocal(idempotencyKey), isFalse);
      expect(LocalIdGenerator.isLocal(operation.id), isTrue);
      expect(idempotencyKey, isNot(operation.id));
    });

    test(
      'still calls ownerImageWriter.addImage with the caller\'s (possibly '
      'still-local) ownerId when it is itself still local — addImage is what '
      'decides whether that needs queuing, not this repository',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(
          () => ownerImageWriter.addImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            mediaId: any(named: 'mediaId'),
          ),
        ).thenAnswer((_) async => const Right(MediaSyncStatus.pending));

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'local-apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        expect(result, isA<Right<Failure, dynamic>>());
        verify(
          () => ownerImageWriter.addImage(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'local-apiary-1',
            mediaId: any(named: 'mediaId'),
          ),
        ).called(1);
      },
    );

    test(
      'links under the owner\'s resolved real id once it has synced, even '
      'though the caller still passes the stale local id it was built with',
      () async {
        when(() => operationQueue.all()).thenAnswer(
          (_) async => [
            OfflineOperation(
              id: 'owner-op-1',
              entityType: 'apiary',
              operationType: OperationType.create,
              payload: const {},
              status: OperationStatus.synced,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              localEntityId: 'local-apiary-1',
              resolvedEntityId: 'srv-apiary-1',
            ),
          ],
        );
        when(
          () => dataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            idempotencyKey: any(named: 'idempotencyKey'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => 'media-1');

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'local-apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        expect(result, isA<Right<Failure, dynamic>>());
        verify(
          () => ownerImageWriter.addImage(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'srv-apiary-1',
            mediaId: 'media-1',
          ),
        ).called(1);
      },
    );
  });

  group('cacheDownloadedMedia', () {
    test(
      'records the local path on the matching cache entry, leaving others untouched',
      () async {
        final other = MediaResponse(
          id: 'media-2',
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          originalFilename: 'other.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 8,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          () => localDataSource.read(),
        ).thenAnswer((_) async => [mediaResponse, other]);

        await repository.cacheDownloadedMedia('media-1', '/media/media-1.jpg');

        final update =
            verify(() => localDataSource.modify(captureAny())).captured.single
                as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
        final written = await update([mediaResponse, other]);
        expect(
          written.firstWhere((r) => r.id == 'media-1').localFilePath,
          '/media/media-1.jpg',
        );
        expect(
          written.firstWhere((r) => r.id == 'media-2').localFilePath,
          isNull,
        );
      },
    );
  });

  group('removeMedia', () {
    test(
      'purges the cache, deletes the local file, and cancels a pending create for a never-synced local id',
      () async {
        final placeholder = mediaResponse.copyWithLocalPath(
          id: 'local-pending-1',
          localFilePath: localFile.path,
        );
        when(
          () => localDataSource.read(),
        ).thenAnswer((_) async => [placeholder]);
        final pendingCreate = OfflineOperation(
          id: 'op-1',
          entityType: 'media',
          operationType: OperationType.create,
          payload: const {},
          status: OperationStatus.pending,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          localEntityId: 'local-pending-1',
        );
        when(
          () => operationQueue.all(),
        ).thenAnswer((_) async => [pendingCreate]);

        final result = await repository.removeMedia('local-pending-1');

        expect(result, isA<Right<Failure, void>>());
        verifyNever(() => dataSource.deleteMedia(any()));
        verify(() => operationQueue.remove('op-1')).called(1);
        verify(() => localMediaStore.delete(localFile.path)).called(1);
      },
    );

    test('deletes a synced id online and purges the cache', () async {
      when(
        () => localDataSource.read(),
      ).thenAnswer((_) async => [mediaResponse]);
      when(() => dataSource.deleteMedia('media-1')).thenAnswer((_) async {});

      final result = await repository.removeMedia('media-1');

      expect(result, isA<Right<Failure, void>>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      final written = await update([mediaResponse]);
      expect(written, isEmpty);
    });

    test(
      'treats a 404 as an already-completed delete and purges the stale local record',
      () async {
        when(
          () => localDataSource.read(),
        ).thenAnswer((_) async => [mediaResponse]);
        when(() => dataSource.deleteMedia('media-1')).thenThrow(
          const ServerException(
            statusCode: 404,
            code: 'media_not_found',
            message: 'not found',
          ),
        );

        final result = await repository.removeMedia('media-1');

        expect(result, isA<Right<Failure, void>>());
      },
    );

    test(
      'queues a delete instead of calling the network when a synced id is removed while offline',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(
          () => localDataSource.read(),
        ).thenAnswer((_) async => [mediaResponse]);

        final result = await repository.removeMedia('media-1');

        expect(result, isA<Right<Failure, void>>());
        verifyNever(() => dataSource.deleteMedia(any()));
        final captured = verify(
          () => operationQueue.enqueue(captureAny()),
        ).captured;
        final operation = captured.single as OfflineOperation;
        expect(operation.entityType, 'media');
        expect(operation.operationType, OperationType.delete);
        expect(operation.localEntityId, 'media-1');
      },
    );
  });
}

extension on MediaResponse {
  MediaResponse copyWithLocalPath({
    required String id,
    required String localFilePath,
    String? ownerId,
  }) {
    return MediaResponse(
      id: id,
      ownerType: ownerType,
      ownerId: ownerId ?? this.ownerId,
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      localFilePath: localFilePath,
    );
  }
}
