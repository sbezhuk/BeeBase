import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IMediaWriter {
  /// Uploads the file at [localFilePath] and links the resulting media id to
  /// [ownerType]/[ownerId] — both halves happen right away, against the
  /// backend; nothing is ever queued for later.
  Future<Either<Failure, MediaAttachment>> attachMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String localFilePath,
    required String originalFilename,
    required String contentType,
    void Function(double progress)? onProgress,
  });

  /// [ownerType]/[ownerId] identify whichever Apiary/Hive [id] is currently
  /// attached to, so the underlying file's removal can also detach it from
  /// that owner's own `images` - see `MediaRepositoryImpl.removeMedia`.
  Future<Either<Failure, void>> removeMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String id,
  });
}
