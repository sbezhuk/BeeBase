import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockMediaImageCache extends Mock implements IMediaImageCache {}

class MockOwnerImageWriter extends Mock implements IOwnerImageWriter {}

class MockApiaryLocalDataSource extends Mock implements IApiaryLocalDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

const _imageUrl = 'https://api.beebase.test/api/v1/media/media-1/download';

MediaResponse _uploaded({String id = 'media-1'}) {
  return MediaResponse(
    id: id,
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    imageUrl: _imageUrl,
  );
}

void main() {
  late MockMediaDataSource dataSource;
  late MockMediaImageCache imageCache;
  late MockOwnerImageWriter ownerImageWriter;
  late MockApiaryLocalDataSource localDataSource;
  late MockNetworkInfo networkInfo;
  late MediaRepositoryImpl repository;

  final sampleLocalMedia = LocalMedia(
    localId: 'media-1',
    serverId: 'media-1',
    ownerType: 'apiary',
    ownerId: 'apiary-1',
    localFilePath: '/cached/path/photo.jpg',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    syncStatus: SyncStatus.synced,
    createdAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(MediaOwnerType.apiary);
    registerFallbackValue(<String>[]);
    registerFallbackValue(sampleLocalMedia);
  });

  setUp(() {
    dataSource = MockMediaDataSource();
    imageCache = MockMediaImageCache();
    ownerImageWriter = MockOwnerImageWriter();
    localDataSource = MockApiaryLocalDataSource();
    networkInfo = MockNetworkInfo();
    repository = MediaRepositoryImpl(
      dataSource: dataSource,
      imageCache: imageCache,
      ownerImageWriter: ownerImageWriter,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );

    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(
      () => imageCache.seedFromFile(
        imageUrl: any(named: 'imageUrl'),
        filePath: any(named: 'filePath'),
      ),
    ).thenAnswer((_) async {});
    when(() => imageCache.evict(any())).thenAnswer((_) async {});
    when(() => imageCache.getCachedFilePath(any()))
        .thenAnswer((_) async => '/cached/path/photo.jpg');
    when(() => localDataSource.getLocalMediaById(any()))
        .thenAnswer((_) async => null);
    when(() => localDataSource.saveLocalMedia(any()))
        .thenAnswer((_) async {});
    when(() => localDataSource.deleteLocalMedia(any()))
        .thenAnswer((_) async {});
  });


  group('getMedia', () {
    test('returns empty list immediately when ids is empty', () async {
      final result = await repository.getMedia(ids: []);

      result.fold(
        (_) => fail('expected Right'),
        (items) => expect(items, isEmpty),
      );
      verifyZeroInteractions(dataSource);
    });

    test('returns mapped items ordered by the given ids', () async {
      final media1 = _uploaded(id: 'media-1');
      final media2 = _uploaded(id: 'media-2');
      when(() => dataSource.listMedia(ids: any(named: 'ids'))).thenAnswer(
        (_) async => [media2, media1],
      );

      final result = await repository.getMedia(ids: ['media-1', 'media-2']);

      result.fold(
        (_) => fail('expected Right'),
        (items) {
          expect(items.length, 2);
          expect(items[0].id, 'media-1');
          expect(items[1].id, 'media-2');
        },
      );
    });

    test('returns ServerFailure when dataSource throws', () async {
      when(() => dataSource.listMedia(ids: any(named: 'ids'))).thenThrow(
        const ServerException(statusCode: 500, code: 'error', message: 'failed'),
      );

      final result = await repository.getMedia(ids: ['media-1']);

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('attachMedia', () {
    test('uploads file, seeds cache, links to owner, and returns entity', () async {
      when(
        () => dataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((_) async => _uploaded(id: 'media-1'));

      when(
        () => ownerImageWriter.addImage(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          mediaId: any(named: 'mediaId'),
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.attachMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        localFilePath: '/path/to/photo.jpg',
        originalFilename: 'photo.jpg',
        contentType: 'image/jpeg',
      );

      result.fold(
        (_) => fail('expected Right'),
        (attachment) => expect(attachment.id, 'media-1'),
      );

      verify(
        () => imageCache.seedFromFile(
          imageUrl: _imageUrl,
          filePath: '/path/to/photo.jpg',
        ),
      ).called(1);
      verify(
        () => ownerImageWriter.addImage(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          mediaId: 'media-1',
        ),
      ).called(1);
    });

    test('returns ServerFailure when upload throws', () async {
      when(
        () => dataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 500, code: 'error', message: 'upload failed'),
      );

      final result = await repository.attachMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        localFilePath: '/path/to/photo.jpg',
        originalFilename: 'photo.jpg',
        contentType: 'image/jpeg',
      );

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(() => ownerImageWriter.addImage(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
        mediaId: any(named: 'mediaId'),
      ));
    });
  });

  group('removeMedia', () {
    test('removes from owner, deletes from dataSource, and evicts from cache', () async {
      when(
        () => ownerImageWriter.removeImage(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          mediaId: any(named: 'mediaId'),
        ),
      ).thenAnswer((_) async => const Right(null));

      when(() => dataSource.listMedia(ids: ['media-1'])).thenAnswer(
        (_) async => [_uploaded(id: 'media-1')],
      );
      when(() => dataSource.deleteMedia('media-1')).thenAnswer((_) async {});

      final result = await repository.removeMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        id: 'media-1',
      );

      expect(result.isRight, isTrue);
      verify(
        () => ownerImageWriter.removeImage(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          mediaId: 'media-1',
        ),
      ).called(1);
      verify(() => dataSource.deleteMedia('media-1')).called(1);
      verify(() => imageCache.evict(_imageUrl)).called(1);
    });

    test('treats 404 from deleteMedia as success', () async {
      when(
        () => ownerImageWriter.removeImage(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          mediaId: any(named: 'mediaId'),
        ),
      ).thenAnswer((_) async => const Right(null));

      when(() => dataSource.listMedia(ids: any(named: 'ids'))).thenAnswer(
        (_) async => [],
      );
      when(() => dataSource.deleteMedia('media-1')).thenThrow(
        const ServerException(statusCode: 404, code: 'not_found', message: 'Not found'),
      );

      final result = await repository.removeMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        id: 'media-1',
      );

      expect(result.isRight, isTrue);
    });

    test('blocks offline removal of server photo and returns failure', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.removeMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        id: 'server-media-1',
      );

      expect(result.isLeft, isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).code, 'cannot_delete_offline');
        },
        (_) => fail('expected Left'),
      );
      verifyNever(() => ownerImageWriter.removeImage(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
        mediaId: any(named: 'mediaId'),
      ));
      verifyNever(() => localDataSource.deleteLocalMedia(any()));
    });

    test('allows offline removal of local-only photo and deletes from localDataSource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(
        () => ownerImageWriter.removeImage(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          mediaId: 'local-media-1',
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await repository.removeMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        id: 'local-media-1',
      );

      expect(result.isRight, isTrue);
      verify(
        () => ownerImageWriter.removeImage(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          mediaId: 'local-media-1',
        ),
      ).called(1);
      verify(() => localDataSource.deleteLocalMedia('local-media-1')).called(1);
    });
  });

  group('getMedia - offline caching', () {
    test('online getMedia caches remote media files and saves LocalMedia to localDataSource', () async {
      final media = _uploaded(id: 'media-1');
      when(() => dataSource.listMedia(ids: ['media-1'])).thenAnswer(
        (_) async => [media],
      );

      final result = await repository.getMedia(ids: ['media-1']);

      expect(result.isRight, isTrue);
      verify(() => imageCache.getCachedFilePath(_imageUrl)).called(1);
      final captured = verify(() => localDataSource.saveLocalMedia(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final saved = captured.first as LocalMedia;
      expect(saved.localId, 'media-1');
      expect(saved.localFilePath, '/cached/path/photo.jpg');
      expect(saved.syncStatus, SyncStatus.synced);
    });

    test('offline getMedia returns cached LocalMedia with localFilePath', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => localDataSource.getLocalMediaById('media-1'))
          .thenAnswer((_) async => sampleLocalMedia);

      final result = await repository.getMedia(ids: ['media-1']);

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (items) {
          expect(items.length, 1);
          expect(items.first.id, 'media-1');
          expect(items.first.localFilePath, '/cached/path/photo.jpg');
        },
      );
      verifyNever(() => dataSource.listMedia(ids: any(named: 'ids')));
    });
  });
}

