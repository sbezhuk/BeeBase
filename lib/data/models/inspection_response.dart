import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inspection_response.g.dart';

@JsonSerializable()
final class InspectionResponse {
  const InspectionResponse({
    required this.id,
    required this.hiveId,
    required this.date,
    required this.type,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  factory InspectionResponse.fromJson(Map<String, dynamic> json) => _$InspectionResponseFromJson(json);

  final String id;

  @JsonKey(name: 'hive_id')
  final String hiveId;

  @JsonKey(name: 'inspected_at')
  final DateTime date;

  final InspectionType type;
  final String notes;

  /// Media attached to this inspection — inspection-service's own source of
  /// truth, returned on every read/write response.
  @EntityImageListConverter()
  @JsonKey(defaultValue: <EntityImageResponse>[])
  final List<EntityImageResponse> images;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$InspectionResponseToJson(this);
}
