import 'package:json_annotation/json_annotation.dart';

part 'hive_inspection_count_response.g.dart';

@JsonSerializable()
final class HiveInspectionCountResponse {
  const HiveInspectionCountResponse({
    required this.hiveId,
    required this.hiveName,
    required this.apiaryId,
    required this.apiaryName,
    required this.inspectionCount,
  });

  factory HiveInspectionCountResponse.fromJson(Map<String, dynamic> json) =>
      _$HiveInspectionCountResponseFromJson(json);

  @JsonKey(name: 'hive_id')
  final String hiveId;

  @JsonKey(name: 'hive_name')
  final String hiveName;

  @JsonKey(name: 'apiary_id')
  final String apiaryId;

  @JsonKey(name: 'apiary_name')
  final String apiaryName;

  @JsonKey(name: 'inspection_count')
  final int inspectionCount;

  Map<String, dynamic> toJson() => _$HiveInspectionCountResponseToJson(this);
}
