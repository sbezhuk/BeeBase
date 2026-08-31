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
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/enum/media_sync_status.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

PaginatedResponse<MediaResponse> _paginated(
  List<MediaResponse> items, {
  required bool hasNext,
  int page = 1,
}) {
  return PaginatedResponse(
    items: items,
    pagination: PaginationMeta(
      page: page,
      limit: 20,
      total: items.length,
      totalPages: 1,
      hasNext: hasNext,
      hasPrevious: page > 1,
    ),
  );
}

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockMediaLocalDataSource extends Mock
    implements LocalDataSource<List<MediaResponse>> {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

void main() {
  late MockMediaDataSource dataSource;
  late MockMediaLocalDataSource localDataSource;
  late MockLocalMediaStore localMediaStore;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late MockOfflineMutationStore offlineMutationStore;
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
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
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
    repository = MediaRepositoryImpl(
      dataSource: dataSource,
      localDataSource: localDataSource,
      localMediaStore: localMediaStore,
      connectivity: connectivity,
      operationQueue: operationQueue,
      offlineMutationStore: offlineMutationStore,
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
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('getMedia', () {
    test(
      'first page replaces the cache and returns only items for the requested owner',
      () async {
        final otherOwner = MediaResponse(
          id: 'media-2',
          ownerType: MediaOwnerType.hive,
          ownerId: 'hive-1',
          originalFilename: 'other.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 512,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          () => dataSource.listMedia(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'apiary-1',
            request: any(named: 'request'),
          ),
        ).thenAnswer(
          (_) async => _paginated([mediaResponse, otherOwner], hasNext: false),
        );

        final result = await repository.getMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          page: 1,
          limit: 20,
        );

        result.fold((_) => fail('expected Right'), (page) {
          expect(page.items.map((attachment) => attachment.id), ['media-1']);
          expect(page.hasNext, isFalse);
        });
      },
    );

    test(
      'maps a thrown exception to a Failure when nothing is cached',
      () async {
        when(
          () => dataSource.listMedia(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            request: any(named: 'request'),
          ),
        ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

        final result = await repository.getMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          page: 1,
          limit: 20,
        );

        expect(result, isA<Left<Failure, dynamic>>());
      },
    );

    test('does not fall back to the cache on a real server failure', () async {
      when(
        () => dataSource.listMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          request: any(named: 'request'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 403,
          code: 'forbidden',
          message: 'not allowed',
        ),
      );

      final result = await repository.getMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        page: 1,
        limit: 20,
      );

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test(
      'reads straight from the cache, filtered to the requested owner, when offline',
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

        final result = await repository.getMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          page: 1,
          limit: 20,
        );

        result.fold(
          (_) => fail('expected Right'),
          (page) => expect(page.items.map((a) => a.id), ['media-1']),
        );
        verifyNever(
          () => dataSource.listMedia(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            request: any(named: 'request'),
          ),
        );
      },
    );

    test('fails when offline with nothing cached for the owner', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.getMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        page: 1,
        limit: 20,
      );

      expect(result, isA<Left<Failure, dynamic>>());
    });
  });

  group('attachMedia', () {
    test(
      'uploads and returns the mapped attachment, preserving the local file path in the cache entry',
      () async {
        when(
          () => dataSource.uploadMedia(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mediaResponse);

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
        });
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
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
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
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

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
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
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
        expect(operation.payload['owner_type'], 'apiary');
        expect(operation.payload['owner_id'], 'apiary-1');
        expect(operation.dependsOnOperationId, isNull);
      },
    );

    test(
      'the queued payload carries a UUID-formatted idempotency key, distinct '
      'from the local-prefixed operation id — MediaOperationHandler sends it '
      'as the media_id form field on upload, and unlike Apiary/Hive (where '
      'the idempotency key only ever travels as an opaque header) a '
      '`local-`-prefixed value there is rejected by the server on every '
      'sync retry, even though it is perfectly fine as this operation\'s own '
      'queue-row id',
      () async {
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
        final idempotencyKey = operation.payload['idempotency_key'] as String;
        expect(idempotencyKey, matches(RegExp(uuidPattern)));
        expect(LocalIdGenerator.isLocal(idempotencyKey), isFalse);
        expect(LocalIdGenerator.isLocal(operation.id), isTrue);
        expect(idempotencyKey, isNot(operation.id));
      },
    );

    test(
      'links the create operation to the owner\'s pending create when ownerId is itself still local',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(() => operationQueue.all()).thenAnswer(
          (_) async => [
            OfflineOperation(
              id: 'owner-op-1',
              entityType: 'apiary',
              operationType: OperationType.create,
              payload: const {},
              status: OperationStatus.pending,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              localEntityId: 'local-apiary-1',
            ),
          ],
        );

        final result = await repository.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'local-apiary-1',
          localFilePath: localFile.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        expect(result, isA<Right<Failure, dynamic>>());
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
        expect(operation.dependsOnOperationId, 'owner-op-1');
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
      'blocks deleting a synced id while offline, without calling the network',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);

        final result = await repository.removeMedia('media-1');

        expect(result, isA<Left<Failure, void>>());
        verifyNever(() => dataSource.deleteMedia(any()));
      },
    );
  });
}

extension on MediaResponse {
  MediaResponse copyWithLocalPath({
    required String id,
    required String localFilePath,
  }) {
    return MediaResponse(
      id: id,
      ownerType: ownerType,
      ownerId: ownerId,
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      localFilePath: localFilePath,
    );
  }
}
