import 'package:json_annotation/json_annotation.dart';

part 'media_upload_form_request.g.dart';

/// Scalar multipart form fields for `POST /media` — the file itself is added
/// separately by the data source since building a `MultipartFile` is async
/// and isn't representable as plain JSON. Upload is owner-less: media-service
/// requires no apiary/hive to exist yet and never accepts one here — an
/// upload is linked to an owner afterward via the owning apiary/hive's own
/// `images` field on `PUT` (see `ApiaryRepositoryImpl.addApiaryImage`/
/// `HiveRepositoryImpl.addHiveImage`), since media-service's own attach
/// endpoint is internal-only now.
@JsonSerializable(includeIfNull: false)
final class MediaUploadFormRequest {
  const MediaUploadFormRequest({this.mediaId});

  factory MediaUploadFormRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaUploadFormRequestFromJson(json);

  /// The idempotency key, sent as a form field (rather than a header, unlike
  /// every other create endpoint) because this request's body is
  /// `multipart/form-data`, not JSON. `null` omits the field entirely rather
  /// than sending it as a JSON `null`.
  @JsonKey(name: 'media_id')
  final String? mediaId;

  Map<String, dynamic> toJson() => _$MediaUploadFormRequestToJson(this);
}
