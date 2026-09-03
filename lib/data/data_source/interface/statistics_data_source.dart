import 'package:beebase/data/models/activity_response.dart';
import 'package:beebase/data/models/apiary_stats_response.dart';
import 'package:beebase/data/models/inspection_stats_response.dart';
import 'package:beebase/data/models/overview_response.dart';

abstract interface class IStatisticsDataSource {
  Future<OverviewResponse> getOverview();

  Future<ApiaryStatsResponse> getApiaryStats();

  Future<InspectionStatsResponse> getInspectionStats();

  Future<ActivityResponse> getActivity({int limit = 10});
}
