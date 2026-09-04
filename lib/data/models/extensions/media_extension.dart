import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/media_attachment.dart';

extension MediaResponseX on MediaResponse {
  MediaAttachment toEntity() => MediaAttachment(
    id: id,
    originalFilename: originalFilename,
    contentType: contentType,
    sizeBytes: sizeBytes,
    imageUrl: imageUrl,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
