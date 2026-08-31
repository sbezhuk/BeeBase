import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'media_upload_request.g.dart';

/// Payload of a queued media `create` [OfflineOperation] — built once in
/// `MediaRepositoryImpl._attachOffline` and read back by
/// `MediaOperationHandler` when `SyncEngine` drains the queue.
@JsonSerializable()
final class MediaUploadRequest {
  const MediaUploadRequest({
    required this.ownerType,
    required this.ownerId,
    required this.localFilePath,
    required this.originalFilename,
    required this.contentType,
    required this.idempotencyKey,
  });

  factory MediaUploadRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaUploadRequestFromJson(json);

  @JsonKey(name: 'owner_type')
  final MediaOwnerType ownerType;

  @JsonKey(name: 'owner_id')
  final String ownerId;

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
