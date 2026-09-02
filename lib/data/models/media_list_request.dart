import 'package:json_annotation/json_annotation.dart';

part 'media_list_request.g.dart';

/// `ids`-filter query parameters for `GET /media` — serialized as a repeated
/// `ids=<uuid>&ids=<uuid>` query string (Dio's default `ListFormat.multi`
/// expands a `List<String>` query value that way), matching media-service's
/// `r.URL.Query()["ids"]` parsing. No longer paginated — this endpoint's
/// result size is naturally bounded by the ids count itself.
@JsonSerializable()
final class MediaListRequest {
  const MediaListRequest({required this.ids});

  factory MediaListRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaListRequestFromJson(json);

  final List<String> ids;

  Map<String, dynamic> toJson() => _$MediaListRequestToJson(this);
}
