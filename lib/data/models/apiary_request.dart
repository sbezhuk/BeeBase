import 'package:json_annotation/json_annotation.dart';

part 'apiary_request.g.dart';

@JsonSerializable()
final class ApiaryRequest {
  const ApiaryRequest({required this.name, this.description, this.location, this.lat, this.lon, this.images});

  factory ApiaryRequest.fromJson(Map<String, dynamic> json) => _$ApiaryRequestFromJson(json);

  final String name;
  final String? description;
  final String? location;
  final double? lat;
  final double? lon;

  /// The desired final set of already-uploaded media ids attached to this
  /// apiary. `null` (the default) leaves currently attached media
  /// untouched — [includeIfNull] omits the key entirely in that case, which
  /// is what apiary-service's `PUT` distinguishes from an explicit `[]`
  /// (detach everything). Never sent on create: apiary-service's create
  /// endpoint has no `images` field, so a caller must create first and PUT
  /// separately to attach photos.
  @JsonKey(includeIfNull: false)
  final List<String>? images;

  Map<String, dynamic> toJson() => _$ApiaryRequestToJson(this);
}
