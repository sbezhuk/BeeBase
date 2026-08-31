import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/media_attachment.dart';

extension MediaResponseX on MediaResponse {
  MediaAttachment toEntity() => MediaAttachment(
    id: id,
    ownerType: ownerType,
    ownerId: ownerId,
    originalFilename: originalFilename,
    contentType: contentType,
    sizeBytes: sizeBytes,
    localFilePath: localFilePath,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
