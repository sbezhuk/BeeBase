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

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$ApiaryResponseToJson(this);
}
