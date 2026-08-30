import 'package:json_annotation/json_annotation.dart';

part 'hive_response.g.dart';

@JsonSerializable()
final class HiveResponse {
  const HiveResponse({
    required this.id,
    required this.apiaryId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HiveResponse.fromJson(Map<String, dynamic> json) =>
      _$HiveResponseFromJson(json);

  final String id;

  @JsonKey(name: 'apiary_id')
  final String apiaryId;

  final String name;
  final String? notes;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$HiveResponseToJson(this);
}
