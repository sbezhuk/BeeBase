import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'attach_media_request.g.dart';

/// Body of `POST /media/{mediaId}/attach` — links an already-uploaded,
/// not-yet-owned file to an apiary or a hive the caller owns. Idempotent
/// server-side: sending the same owner again just confirms the existing link.
@JsonSerializable()
final class AttachMediaRequest {
  const AttachMediaRequest({required this.ownerType, required this.ownerId});

  factory AttachMediaRequest.fromJson(Map<String, dynamic> json) =>
      _$AttachMediaRequestFromJson(json);

  @JsonKey(name: 'owner_type')
  final MediaOwnerType ownerType;

  @JsonKey(name: 'owner_id')
  final String ownerId;

  Map<String, dynamic> toJson() => _$AttachMediaRequestToJson(this);
}
