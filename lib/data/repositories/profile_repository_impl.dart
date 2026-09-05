import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/extensions/profile_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/domain/entity/profile.dart';
import 'package:beebase/domain/repositories/account_deleter.dart';
import 'package:beebase/domain/repositories/profile_reader.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:path/path.dart' as p;

final class ProfileRepositoryImpl extends Repository
    implements IProfileReader, IProfileWriter, IAccountDeleter {
  ProfileRepositoryImpl({
    required this.dataSource,
    required this.mediaDataSource,
    required this.imageCache,
    required this.apiaryDatabase,
  });

  final IProfileDataSource dataSource;

  /// Owns the offline SQLite database wiped on [deleteAccount] — not needed
  /// by [getProfile]/[updateProfile], only by account deletion's local
  /// cleanup.
  final ApiaryDatabase apiaryDatabase;

  /// Uploads a picked avatar's raw bytes. Deliberately the narrow media
  /// data source, not `IMediaWriter` — a profile's avatar is a single field
  /// on the user, not an entry in some owner's `images` list, so there is
  /// nothing to link it to via `IOwnerImageWriter` (see `MediaOwnerType`,
  /// which only knows about apiaries and hives). `PUT /api/v1/profile`
  /// itself carries the resulting media id.
  final IMediaDataSource mediaDataSource;

  /// Seeded from the picked file the moment the upload succeeds, so
  /// `ProfileAvatar` renders the new avatar without a round trip.
  final IMediaImageCache imageCache;

  @override
  Future<Either<Failure, Profile>> getProfile() {
    return on(() async => (await dataSource.getProfile()).toEntity());
  }

  @override
  Future<Either<Failure, void>> deleteAccount({required String otp}) {
    return on(() async {
      await dataSource.deleteAccount(otp: otp);
      await apiaryDatabase.deleteDatabaseFile();
      await imageCache.clearAll();
    });
  }

  @override
  Future<Either<Failure, Profile>> updateProfile({
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    bool removeAvatar = false,
  }) {
    return on(() async {
      // Per auth-service's own contract: null/omitted leaves the current
      // avatar untouched, '' removes it, an id replaces it — never resend
      // the current id, there's no need to.
      final uploaded = removeAvatar || newAvatarLocalFilePath == null
          ? null
          : await _uploadAvatar(newAvatarLocalFilePath);
      final avatar = removeAvatar ? '' : uploaded?.id;
      final response = await dataSource.updateProfile(
        ProfileUpdateRequest(
          firstName: firstName,
          lastName: lastName,
          avatar: avatar,
        ),
      );
      if (uploaded != null && newAvatarLocalFilePath != null) {
        await _seedImageCache(uploaded, newAvatarLocalFilePath);
      }
      return response.toEntity();
    });
  }

  Future<MediaResponse> _uploadAvatar(String localFilePath) {
    final originalFilename = p.basename(localFilePath);
    return mediaDataSource.uploadMedia(
      filePath: localFilePath,
      originalFilename: originalFilename,
      contentType: contentTypeFromExtension(
        extensionFromFilename(originalFilename),
      ),
    );
  }

  Future<void> _seedImageCache(
    MediaResponse uploaded,
    String localFilePath,
  ) async {
    final imageUrl = uploaded.imageUrl;
    if (imageUrl == null) return;
    await imageCache.seedFromFile(imageUrl: imageUrl, filePath: localFilePath);
  }
}
