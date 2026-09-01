import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'media_upload_form_request.g.dart';

/// Scalar multipart form fields for `POST /media` — the file itself is added
/// separately by the data source since building a `MultipartFile` is async
/// and isn't representable as plain JSON.
@JsonSerializable(includeIfNull: false)
final class MediaUploadFormRequest {
  const MediaUploadFormRequest({
    required this.ownerType,
    required this.ownerId,
    this.mediaId,
  });

  factory MediaUploadFormRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaUploadFormRequestFromJson(json);

  @JsonKey(name: 'owner_type')
  final MediaOwnerType ownerType;

  @JsonKey(name: 'owner_id')
  final String ownerId;

  /// The idempotency key, sent as a form field (rather than a header, unlike
  /// every other create endpoint) because this request's body is
  /// `multipart/form-data`, not JSON. `null` omits the field entirely rather
  /// than sending it as a JSON `null`.
  @JsonKey(name: 'media_id')
  final String? mediaId;

  Map<String, dynamic> toJson() => _$MediaUploadFormRequestToJson(this);
}
