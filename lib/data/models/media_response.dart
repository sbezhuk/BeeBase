import 'package:json_annotation/json_annotation.dart';

part 'media_response.g.dart';

/// Doubles as this feature's cached-list DTO, not just the wire DTO — see
/// [localFilePath]. Has no notion of an owning apiary/hive - media-service
/// dropped `owner_type`/`owner_id` from this response entirely; that
/// relationship is now tracked only in `ApiaryResponse.images`/
/// `HiveResponse.images`.
@JsonSerializable()
final class MediaResponse {
  const MediaResponse({
    required this.id,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
    this.localFilePath,
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

  /// Local-only, never present in the server's JSON — a not-yet-uploaded (or
  /// just-uploaded, not-yet-cleaned-up) photo's local file path, so it can be
  /// rendered via `Image.file` immediately instead of waiting on a download
  /// round trip. Persisted across the cached-list round trip
  /// ([toJson]/[fromJson]) exactly like every other field here, since this
  /// DTO is what `LocalDataSource<List<MediaResponse>>` actually stores —
  /// only never sent over the wire, since uploads are built as
  /// `multipart/form-data` field-by-field, never from this class's [toJson].
  @JsonKey(name: 'local_file_path')
  final String? localFilePath;

  Map<String, dynamic> toJson() => _$MediaResponseToJson(this);

  MediaResponse copyWith({String? localFilePath}) {
    return MediaResponse(
      id: id,
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}
