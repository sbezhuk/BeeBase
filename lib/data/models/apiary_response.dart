import 'package:json_annotation/json_annotation.dart';

part 'apiary_response.g.dart';

@JsonSerializable()
final class ApiaryResponse {
  const ApiaryResponse({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.lat,
    this.lon,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  factory ApiaryResponse.fromJson(Map<String, dynamic> json) => _$ApiaryResponseFromJson(json);

  final String id;
  final String name;

  final String? description;
  final String? location;
  final double? lat;
  final double? lon;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Media ids currently attached to this apiary — computed live from
  /// media-service on every server read, never stored on the apiary row
  /// itself, so this is only as fresh as the last fetch. Defaults to `[]`
  /// for a response rebuilt locally from a plain field-edit request (see
  /// `ApiaryRequestX.toResponse`), which never carries a caller-supplied
  /// value for it.
  @JsonKey(defaultValue: <String>[])
  final List<String> images;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$ApiaryResponseToJson(this);
}
