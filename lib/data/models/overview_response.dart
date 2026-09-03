import 'package:json_annotation/json_annotation.dart';

part 'overview_response.g.dart';

@JsonSerializable()
final class OverviewResponse {
  const OverviewResponse({
    required this.totalApiaries,
    required this.totalHives,
    required this.totalInspections,
    required this.inspectionsLast7Days,
    required this.inspectionsThisMonth,
    required this.inspectionsThisYear,
    required this.apiariesWithoutHives,
    required this.hivesWithoutInspections,
    required this.avgHivesPerApiary,
    required this.avgInspectionsPerHive,
    this.latestInspectionAt,
  });

  factory OverviewResponse.fromJson(Map<String, dynamic> json) =>
      _$OverviewResponseFromJson(json);

  @JsonKey(name: 'total_apiaries')
  final int totalApiaries;

  @JsonKey(name: 'total_hives')
  final int totalHives;

  @JsonKey(name: 'total_inspections')
  final int totalInspections;

  @JsonKey(name: 'inspections_last_7_days')
  final int inspectionsLast7Days;

  @JsonKey(name: 'inspections_this_month')
  final int inspectionsThisMonth;

  @JsonKey(name: 'inspections_this_year')
  final int inspectionsThisYear;

  @JsonKey(name: 'apiaries_without_hives')
  final int apiariesWithoutHives;

  @JsonKey(name: 'hives_without_inspections')
  final int hivesWithoutInspections;

  @JsonKey(name: 'avg_hives_per_apiary')
  final double avgHivesPerApiary;

  @JsonKey(name: 'avg_inspections_per_hive')
  final double avgInspectionsPerHive;

  @JsonKey(name: 'latest_inspection_at')
  final DateTime? latestInspectionAt;

  Map<String, dynamic> toJson() => _$OverviewResponseToJson(this);
}
