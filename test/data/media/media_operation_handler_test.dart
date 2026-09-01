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
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockMediaLocalDataSource extends Mock implements LocalDataSource<List<MediaResponse>> {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockOperationQueue extends Mock implements OperationQueue {}

OfflineOperation _createOp({
  String id = 'op-1',
  String localEntityId = 'local-1',
  String ownerId = 'apiary-1',
  String ownerType = 'APIARY',
  String? dependsOnOperationId,
  String idempotencyKey = 'idem-key-1',
}) {
  return OfflineOperation(
    id: id,
    entityType: 'media',
    operationType: OperationType.create,
    payload: {
      'owner_type': ownerType,
      'owner_id': ownerId,
      'local_file_path': '/tmp/photo.jpg',
      'original_filename': 'photo.jpg',
      'content_type': 'image/jpeg',
      'idempotency_key': idempotencyKey,
    },
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
    dependsOnOperationId: dependsOnOperationId,
  );
}

void main() {
  late MockMediaDataSource dataSource;
  late MockMediaLocalDataSource localDataSource;
  late MockLocalMediaStore localMediaStore;
  late MockOperationQueue operationQueue;
  late ApiaryListRefreshNotifier apiaryRefreshNotifier;
  late HiveListRefreshNotifier hiveRefreshNotifier;
  late MediaOperationHandler handler;

  final serverResponse = MediaResponse(
    id: 'media-server-1',
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 2048,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(_createOp());
    registerFallbackValue(MediaOwnerType.apiary);
  });

  setUp(() {
    dataSource = MockMediaDataSource();
    localDataSource = MockMediaLocalDataSource();
    localMediaStore = MockLocalMediaStore();
    operationQueue = MockOperationQueue();
    apiaryRefreshNotifier = ApiaryListRefreshNotifier();
    hiveRefreshNotifier = HiveListRefreshNotifier();
    handler = MediaOperationHandler(
      dataSource: dataSource,
      localDataSource: localDataSource,
      localMediaStore: localMediaStore,
      operationQueue: operationQueue,
      apiaryRefreshNotifier: apiaryRefreshNotifier,
      hiveRefreshNotifier: hiveRefreshNotifier,
    );

    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update = invocation.positionalArguments.single as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      await update(await localDataSource.read());
    });
    when(() => localMediaStore.delete(any())).thenAnswer((_) async {});
    when(
      () => localMediaStore.adopt(
        any(),
        id: any(named: 'id'),
        extension: any(named: 'extension'),
      ),
    ).thenAnswer((invocation) async => '/media/${invocation.namedArguments[#id]}.jpg');
    when(() => operationQueue.update(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    apiaryRefreshNotifier.dispose();
    hiveRefreshNotifier.dispose();
  });

  test('entityType is media', () {
    expect(handler.entityType, 'media');
  });

  group('create', () {
    test('uploads with the request\'s idempotency key — never the local '
        'operation id, which is `local-`-prefixed and gets rejected by the '
        'server when sent as the media_id form field (unlike Apiary/Hive, '
        'where the idempotency key only ever travels as an opaque header)', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      final result = await handler.handle(_createOp(id: 'op-99', idempotencyKey: 'ab12cd34-ef56-4789-a012-3456789abcde'));

      expect(result, isA<OperationSuccess>());
      expect((result as OperationSuccess).resolvedEntityId, 'media-server-1');
      verify(
        () => dataSource.uploadMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
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
      verify(() => localMediaStore.adopt('/tmp/photo.jpg', id: 'media-server-1', extension: 'jpg')).called(1);
      verifyNever(() => localMediaStore.delete(any()));
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<MediaResponse>> Function(List<MediaResponse>?);
      final written = await update([]);
      expect(written.single.id, 'media-server-1');
      expect(written.single.localFilePath, '/media/media-server-1.jpg');
    });

    test('notifies the apiary list refresh notifier on success so an open '
        'gallery for that owner reloads', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);
      final notified = expectLater(apiaryRefreshNotifier.onChanged, emits(anything));

      await handler.handle(_createOp(ownerType: 'APIARY'));

      await notified;
    });

    test('notifies the hive list refresh notifier on success when the photo '
        'belongs to a hive', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => MediaResponse(
          id: 'media-server-2',
          ownerType: MediaOwnerType.hive,
          ownerId: 'hive-1',
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final notified = expectLater(hiveRefreshNotifier.onChanged, emits(anything));

      await handler.handle(_createOp(ownerType: 'HIVE', ownerId: 'hive-1'));

      await notified;
    });

    test('resolves the real owner id once its dependency has synced', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(() => operationQueue.find('dep-op')).thenAnswer(
        (_) async => OfflineOperation(
          id: 'dep-op',
          entityType: 'apiary',
          operationType: OperationType.create,
          payload: const {},
          status: OperationStatus.synced,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          resolvedEntityId: 'apiary-real-42',
        ),
      );
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      await handler.handle(_createOp(ownerId: 'local-apiary-1', dependsOnOperationId: 'dep-op'));

      verify(
        () => dataSource.uploadMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-real-42',
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });

    test('is a retryable failure when the owner dependency has not synced yet', () async {
      when(() => operationQueue.find('dep-op')).thenAnswer((_) async => null);

      final result = await handler.handle(_createOp(ownerId: 'local-apiary-1', dependsOnOperationId: 'dep-op'));

      expect(result, isA<OperationRetryableFailure>());
      verifyNever(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
        ),
      );
    });

    test('classifies a ServerException as a permanent failure', () async {
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const ServerException(statusCode: 415, code: 'unsupported_file_type', message: 'bad file'));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => localDataSource.modify(any()));
      verifyNever(() => localMediaStore.delete(any()));
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationRetryableFailure>());
    });

    test('marks the operation synced in the queue before notifying, so a live refresh sees it as already synced', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.uploadMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      await handler.handle(_createOp());

      final syncedUpdate = verify(() => operationQueue.update(captureAny())).captured.single as OfflineOperation;
      expect(syncedUpdate.status, OperationStatus.synced);
      expect(syncedUpdate.resolvedEntityId, 'media-server-1');
    });
  });

  test('update operations are not supported', () async {
    final updateOp = _createOp().copyWith(operationType: OperationType.update);

    final result = await handler.handle(updateOp);

    expect(result, isA<OperationPermanentFailure>());
  });

  test('delete operations are not supported yet', () async {
    final deleteOp = _createOp().copyWith(operationType: OperationType.delete);

    final result = await handler.handle(deleteOp);

    expect(result, isA<OperationPermanentFailure>());
  });
}
