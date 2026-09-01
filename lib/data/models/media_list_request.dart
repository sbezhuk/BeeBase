import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'media_list_request.g.dart';

/// Owner-scope query parameters for `GET /media` — merged with [PageRequest]
/// at the call site since pagination is generic across every list endpoint.
@JsonSerializable()
final class MediaListRequest {
  const MediaListRequest({required this.ownerType, required this.ownerId});

  factory MediaListRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaListRequestFromJson(json);

  @JsonKey(name: 'owner_type')
  final MediaOwnerType ownerType;

  @JsonKey(name: 'owner_id')
  final String ownerId;

  Map<String, dynamic> toJson() => _$MediaListRequestToJson(this);
}
