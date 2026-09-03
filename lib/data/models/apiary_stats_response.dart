import 'package:beebase/data/models/apiary_hive_count_response.dart';
import 'package:json_annotation/json_annotation.dart';

part 'apiary_stats_response.g.dart';

@JsonSerializable(explicitToJson: true)
final class ApiaryStatsResponse {
  const ApiaryStatsResponse({
    required this.totalApiaries,
    required this.apiariesWithoutHives,
    this.apiaryWithMostHives,
    required this.hiveDistribution,
  });

  factory ApiaryStatsResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiaryStatsResponseFromJson(json);

  @JsonKey(name: 'total_apiaries')
  final int totalApiaries;

  @JsonKey(name: 'apiaries_without_hives')
  final int apiariesWithoutHives;

  @JsonKey(name: 'apiary_with_most_hives')
  final ApiaryHiveCountResponse? apiaryWithMostHives;

  @JsonKey(name: 'hive_distribution')
  final List<ApiaryHiveCountResponse> hiveDistribution;

  Map<String, dynamic> toJson() => _$ApiaryStatsResponseToJson(this);
}
