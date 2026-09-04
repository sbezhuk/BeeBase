import 'package:beebase/data/models/entity_image_response.dart';
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
    this.images = const [],
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

  /// Media attached to this hive — hive-service's own source of truth,
  /// returned on every read/write response.
  @EntityImageListConverter()
  @JsonKey(defaultValue: <EntityImageResponse>[])
  final List<EntityImageResponse> images;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$HiveResponseToJson(this);
}
