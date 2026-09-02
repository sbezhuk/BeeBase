import 'dart:async';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/media/media_operation_handler.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockMediaLocalDataSource extends Mock
    implements LocalDataSource<List<MediaResponse>> {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockOperationQueue extends Mock implements OperationQueue {}

OfflineOperation _createOp({
  String id = 'op-1',
  String localEntityId = 'local-1',
  String idempotencyKey = 'idem-key-1',
}) {
  return OfflineOperation(
    id: id,
    entityType: 'media',
    operationType: OperationType.create,
    payload: {
      'local_file_path': '/tmp/photo.jpg',
      'original_filename': 'photo.jpg',
      'content_type': 'image/jpeg',
      'idempotency_key': idempotencyKey,
    },
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
  );
}

OfflineOperation _deleteOp({
  String id = 'op-1',
  String? localEntityId = 'media-1',
}) {
  return OfflineOperation(
    id: id,
    entityType: 'media',
    operationType: OperationType.delete,
    payload: const {},
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
  );
}

MediaResponse _placeholder({String id = 'local-1'}) {
  return MediaResponse(
    id: id,
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 2048,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  late MockMediaDataSource dataSource;
  late MockMediaLocalDataSource localDataSource;
  late MockLocalMediaStore localMediaStore;
  late MockOperationQueue operationQueue;
  late MediaOperationHandler handler;

  setUpAll(() {
    registerFallbackValue(_createOp());
  });

  setUp(() {
    dataSource = MockMediaDataSource();
    localDataSource = MockMediaLocalDataSource();
    localMediaStore = MockLocalMediaStore();
    operationQueue = MockOperationQueue();
    handler = MediaOperationHandler(
      dataSource: dataSource,
      localDataSource: localDataSource,
      localMediaStore: localMediaStore,
      operationQueue: operationQueue,
    );

    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update =
          invocation.positionalArguments.single
              as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      await update(await localDataSource.read());
    });
    when(() => localMediaStore.delete(any())).thenAnswer((_) async {});
    when(
      () => localMediaStore.adopt(
        any(),
        id: any(named: 'id'),
        extension: any(named: 'extension'),
      ),
    ).thenAnswer(
      (invocation) async => '/media/${invocation.namedArguments[#id]}.jpg',
    );
    when(() => operationQueue.update(any())).thenAnswer((_) async {});
  });

  test('entityType is media', () {
    expect(handler.entityType, 'media');
  });

  group('create', () {
    test('uploads with the request\'s idempotency key — never the local '
        'operation id, which is `local-`-prefixed and gets rejected by the '
        'server when sent as the media_id form field — then adopts the '
        'staged file onto the uploaded id\'s cache path, replacing the '
        'placeholder in the local cache', () async {
      when(
        () => localDataSource.read(),
      ).thenAnswer((_) async => [_placeholder()]);
      when(
        () => dataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => 'media-server-1');

      final result = await handler.handle(
        _createOp(
          id: 'op-99',
          idempotencyKey: 'ab12cd34-ef56-4789-a012-3456789abcde',
        ),
      );

      expect(result, isA<OperationSuccess>());
      expect((result as OperationSuccess).resolvedEntityId, 'media-server-1');
      verify(
        () => dataSource.uploadMedia(
          filePath: '/tmp/photo.jpg',
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
          idempotencyKey: 'ab12cd34-ef56-4789-a012-3456789abcde',
        ),
      ).called(1);
      // Adopted (renamed) onto the server id's deterministic cache path,
      // not deleted — see LocalMediaStore.adopt — so the photo stays
      // available offline right after syncing instead of needing a
      // redundant re-download.
      verify(
        () => localMediaStore.adopt(
          '/tmp/photo.jpg',
          id: 'media-server-1',
          extension: 'jpg',
        ),
      ).called(1);
      verifyNever(() => localMediaStore.delete(any()));
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      final written = await update([_placeholder()]);
      expect(written.single.id, 'media-server-1');
      expect(written.single.localFilePath, '/media/media-server-1.jpg');
    });

    test('a missing placeholder (cache cleared out from under the pending '
        'operation) is a no-op — the upload still succeeds', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => 'media-server-1');

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationSuccess>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      expect(await update([]), isEmpty);
    });

    test('classifies a ServerException as a permanent failure', () async {
      when(
        () => dataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 415,
          code: 'unsupported_file_type',
          message: 'bad file',
        ),
      );

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => localDataSource.modify(any()));
      verifyNever(() => localMediaStore.delete(any()));
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(
        () => dataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationRetryableFailure>());
    });

    test(
      'marks the operation synced in the queue with the resolved (uploaded) id',
      () async {
        when(
          () => localDataSource.read(),
        ).thenAnswer((_) async => [_placeholder()]);
        when(
          () => dataSource.uploadMedia(
            filePath: any(named: 'filePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => 'media-server-1');

        await handler.handle(_createOp());

        final syncedUpdate =
            verify(() => operationQueue.update(captureAny())).captured.single
                as OfflineOperation;
        expect(syncedUpdate.status, OperationStatus.synced);
        expect(syncedUpdate.resolvedEntityId, 'media-server-1');
      },
    );
  });

  group('delete', () {
    test('deletes the file and marks the operation synced', () async {
      when(() => dataSource.deleteMedia(any())).thenAnswer((_) async {});

      final result = await handler.handle(_deleteOp(localEntityId: 'media-1'));

      expect(result, isA<OperationSuccess>());
      verify(() => dataSource.deleteMedia('media-1')).called(1);
      final syncedUpdate =
          verify(() => operationQueue.update(captureAny())).captured.single
              as OfflineOperation;
      expect(syncedUpdate.status, OperationStatus.synced);
    });

    test('a 404 means the server already forgot the file — treated as an '
        'already-completed delete', () async {
      when(() => dataSource.deleteMedia(any())).thenThrow(
        const ServerException(
          statusCode: 404,
          code: 'not_found',
          message: 'gone',
        ),
      );

      final result = await handler.handle(_deleteOp(localEntityId: 'media-1'));

      expect(result, isA<OperationSuccess>());
      final syncedUpdate =
          verify(() => operationQueue.update(captureAny())).captured.single
              as OfflineOperation;
      expect(syncedUpdate.status, OperationStatus.synced);
    });

    test('a non-404 ServerException is a permanent failure', () async {
      when(() => dataSource.deleteMedia(any())).thenThrow(
        const ServerException(
          statusCode: 500,
          code: 'server_error',
          message: 'boom',
        ),
      );

      final result = await handler.handle(_deleteOp(localEntityId: 'media-1'));

      expect(result, isA<OperationPermanentFailure>());
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(
        () => dataSource.deleteMedia(any()),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_deleteOp(localEntityId: 'media-1'));

      expect(result, isA<OperationRetryableFailure>());
    });

    test('a missing target id is a permanent failure', () async {
      final result = await handler.handle(_deleteOp(localEntityId: null));

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => dataSource.deleteMedia(any()));
    });
  });

  test('update operations are not supported', () async {
    final updateOp = _createOp().copyWith(operationType: OperationType.update);

    final result = await handler.handle(updateOp);

    expect(result, isA<OperationPermanentFailure>());
  });

  test(
    'imageAdd is not a media operation — only apiary/hive operations are ever queued as imageAdd',
    () async {
      final imageAddOp = _createOp().copyWith(
        operationType: OperationType.imageAdd,
      );

      final result = await handler.handle(imageAddOp);

      expect(result, isA<OperationPermanentFailure>());
    },
  );
}
