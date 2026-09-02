import 'package:json_annotation/json_annotation.dart';

part 'media_upload_request.g.dart';

/// Payload of a queued media `create` [OfflineOperation] — built once in
/// `MediaRepositoryImpl` and read back by `MediaOperationHandler` when
/// `SyncEngine` drains the queue. Deliberately owner-less: uploading a file
/// never needs an apiary/hive to exist, so this operation has no
/// [OfflineOperation.dependsOnOperationId] either — linking the uploaded id
/// to an owner is a separate, later step (see `OperationType.imageAdd`).
@JsonSerializable()
final class MediaUploadRequest {
  const MediaUploadRequest({
    required this.localFilePath,
    required this.originalFilename,
    required this.contentType,
    required this.idempotencyKey,
  });

  factory MediaUploadRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaUploadRequestFromJson(json);

  @JsonKey(name: 'local_file_path')
  final String localFilePath;

  @JsonKey(name: 'original_filename')
  final String originalFilename;

  @JsonKey(name: 'content_type')
  final String contentType;

  /// Generated once via [IdempotencyKeyGenerator] when this request is first
  /// built (see `MediaRepositoryImpl._attachOffline`) and persisted here so
  /// it stays the same across every `SyncEngine` retry of the same queued
  /// operation. Deliberately *not* [OfflineOperation.id]: that id is
  /// `local-`-prefixed (see `LocalIdGenerator`) and gets sent to the server
  /// as the literal `media_id` form field — unlike Apiary/Hive, where the
  /// idempotency key only ever travels as an opaque header — so it must
  /// actually be a well-formed UUID or the upload is rejected every time.
  @JsonKey(name: 'idempotency_key')
  final String idempotencyKey;

  Map<String, dynamic> toJson() => _$MediaUploadRequestToJson(this);
}
