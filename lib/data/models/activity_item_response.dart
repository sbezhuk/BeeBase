import 'package:json_annotation/json_annotation.dart';

part 'activity_item_response.g.dart';

@JsonSerializable()
final class ActivityItemResponse {
  const ActivityItemResponse({
    required this.inspectionId,
    required this.inspectedAt,
    required this.hiveId,
    required this.hiveName,
    required this.apiaryId,
    required this.apiaryName,
    required this.notes,
  });

  factory ActivityItemResponse.fromJson(Map<String, dynamic> json) =>
      _$ActivityItemResponseFromJson(json);

  @JsonKey(name: 'inspection_id')
  final String inspectionId;

  @JsonKey(name: 'inspected_at')
  final DateTime inspectedAt;

  @JsonKey(name: 'hive_id')
  final String hiveId;

  @JsonKey(name: 'hive_name')
  final String hiveName;

  @JsonKey(name: 'apiary_id')
  final String apiaryId;

  @JsonKey(name: 'apiary_name')
  final String apiaryName;

  final String notes;

  Map<String, dynamic> toJson() => _$ActivityItemResponseToJson(this);
}
