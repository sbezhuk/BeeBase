import 'package:json_annotation/json_annotation.dart';

part 'apiary_response.g.dart';

@JsonSerializable()
final class ApiaryResponse {
  const ApiaryResponse({
    required this.id,
    required this.name,
    this.notes,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApiaryResponse.fromJson(Map<String, dynamic> json) => _$ApiaryResponseFromJson(json);

  final String id;
  final String name;

  final String? notes;
  final String? location;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$ApiaryResponseToJson(this);
}
