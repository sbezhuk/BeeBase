import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IMediaWriter {
  Future<Either<Failure, MediaAttachment>> attachMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String localFilePath,
    required String originalFilename,
    required String contentType,
    void Function(double progress)? onProgress,
  });

  Future<Either<Failure, void>> removeMedia(String id);
}
