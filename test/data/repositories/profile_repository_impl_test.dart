import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/repositories/profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileDataSource extends Mock implements IProfileDataSource {}

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockMediaImageCache extends Mock implements IMediaImageCache {}

const _avatarImageUrl = 'https://api.beebase.test/api/v1/media/media-2/download';

MediaResponse _uploadedAvatar() {
  return MediaResponse(
    id: 'media-2',
    originalFilename: 'avatar.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 512,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    imageUrl: _avatarImageUrl,
  );
}

void main() {
  late MockProfileDataSource dataSource;
  late MockMediaDataSource mediaDataSource;
  late MockMediaImageCache imageCache;
  late ProfileRepositoryImpl repository;

  final profileResponse = ProfileResponse(
    id: 'user-1',
    email: 'john@example.com',
    firstName: 'John',
    lastName: 'Doe',
    avatar: 'media-1',
  );

  setUpAll(() {
    registerFallbackValue(const ProfileUpdateRequest(firstName: 'fallback', lastName: 'fallback'));
  });

  setUp(() {
    dataSource = MockProfileDataSource();
    mediaDataSource = MockMediaDataSource();
    imageCache = MockMediaImageCache();
    repository = ProfileRepositoryImpl(
      dataSource: dataSource,
      mediaDataSource: mediaDataSource,
      imageCache: imageCache,
    );
    when(
      () => imageCache.seedFromFile(
        imageUrl: any(named: 'imageUrl'),
        filePath: any(named: 'filePath'),
      ),
    ).thenAnswer((_) async {});
  });

  group('getProfile', () {
    test('returns mapped Profile on success', () async {
      when(() => dataSource.getProfile()).thenAnswer((_) async => profileResponse);

      final result = await repository.getProfile();

      result.fold(
        (_) => fail('expected Right'),
        (profile) {
          expect(profile.id, 'user-1');
          expect(profile.firstName, 'John');
          expect(profile.lastName, 'Doe');
        },
      );
    });

    test('returns ServerFailure when dataSource throws', () async {
      when(() => dataSource.getProfile()).thenThrow(
        const ServerException(statusCode: 500, code: 'error', message: 'failed'),
      );

      final result = await repository.getProfile();

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateProfile', () {
    test('updates fields without touching avatar when no avatar given', () async {
      when(() => dataSource.updateProfile(any())).thenAnswer((_) async => profileResponse);

      final result = await repository.updateProfile(
        firstName: 'Jane',
        lastName: 'Smith',
      );

      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile.id, 'user-1'),
      );
      final captured = verify(() => dataSource.updateProfile(captureAny())).captured;
      final request = captured.first as ProfileUpdateRequest;
      expect(request.firstName, 'Jane');
      expect(request.lastName, 'Smith');
      expect(request.avatar, isNull);
    });

    test('clears avatar when removeAvatar is true', () async {
      when(() => dataSource.updateProfile(any())).thenAnswer((_) async => profileResponse);

      final result = await repository.updateProfile(
        firstName: 'John',
        lastName: 'Doe',
        removeAvatar: true,
      );

      expect(result.isRight, isTrue);
      final captured = verify(() => dataSource.updateProfile(captureAny())).captured;
      final request = captured.first as ProfileUpdateRequest;
      expect(request.avatar, '');
      verifyNever(() => mediaDataSource.uploadMedia(
        filePath: any(named: 'filePath'),
        originalFilename: any(named: 'originalFilename'),
        contentType: any(named: 'contentType'),
      ));
    });

    test('uploads avatar and seeds cache when newAvatarLocalFilePath is provided', () async {
      when(
        () => mediaDataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
        ),
      ).thenAnswer((_) async => _uploadedAvatar());
      when(() => dataSource.updateProfile(any())).thenAnswer((_) async => profileResponse);

      final result = await repository.updateProfile(
        firstName: 'John',
        lastName: 'Doe',
        newAvatarLocalFilePath: '/path/to/avatar.jpg',
      );

      expect(result.isRight, isTrue);
      final captured = verify(() => dataSource.updateProfile(captureAny())).captured;
      final request = captured.first as ProfileUpdateRequest;
      expect(request.avatar, 'media-2');
      verify(
        () => imageCache.seedFromFile(
          imageUrl: _avatarImageUrl,
          filePath: '/path/to/avatar.jpg',
        ),
      ).called(1);
    });
  });
}
