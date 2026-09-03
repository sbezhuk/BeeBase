import 'package:beebase/data/models/day_count_response.dart';
import 'package:beebase/data/models/hive_inspection_count_response.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inspection_stats_response.g.dart';

@JsonSerializable(explicitToJson: true)
final class InspectionStatsResponse {
  const InspectionStatsResponse({
    required this.totalInspections,
    required this.inspectionsLast7Days,
    required this.inspectionsThisMonth,
    required this.inspectionsThisYear,
    this.hiveWithMostInspections,
    this.latestInspectionAt,
    required this.activityLast30Days,
  });

  factory InspectionStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$InspectionStatsResponseFromJson(json);

  @JsonKey(name: 'total_inspections')
  final int totalInspections;

  @JsonKey(name: 'inspections_last_7_days')
  final int inspectionsLast7Days;

  @JsonKey(name: 'inspections_this_month')
  final int inspectionsThisMonth;

  @JsonKey(name: 'inspections_this_year')
  final int inspectionsThisYear;

  @JsonKey(name: 'hive_with_most_inspections')
  final HiveInspectionCountResponse? hiveWithMostInspections;

  @JsonKey(name: 'latest_inspection_at')
  final DateTime? latestInspectionAt;

  @JsonKey(name: 'activity_last_30_days')
  final List<DayCountResponse> activityLast30Days;

  Map<String, dynamic> toJson() => _$InspectionStatsResponseToJson(this);
}
