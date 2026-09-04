import 'package:json_annotation/json_annotation.dart';

part 'media_response.g.dart';

/// media-service's own media resource. Has no notion of an owning
/// apiary/hive - media-service dropped `owner_type`/`owner_id` from this
/// response entirely; that relationship is now tracked only in
/// `ApiaryResponse.images`/`HiveResponse.images`.
@JsonSerializable()
final class MediaResponse {
  const MediaResponse({
    required this.id,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  factory MediaResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaResponseFromJson(json);

  final String id;

  @JsonKey(name: 'original_filename')
  final String originalFilename;

  @JsonKey(name: 'content_type')
  final String contentType;

  @JsonKey(name: 'size_bytes')
  final int sizeBytes;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  /// The authenticated URL this photo is fetched and displayed from — always
  /// media-service's own `GET /api/v1/media/{id}/download`, rebuilt by the
  /// server on every response, which is why it's read from here rather than
  /// assembled from [id] client-side.
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  Map<String, dynamic> toJson() => _$MediaResponseToJson(this);
}
