import 'package:beebase/data/models/activity_item_response.dart';
import 'package:beebase/data/models/apiary_hive_count_response.dart';
import 'package:beebase/data/models/apiary_stats_response.dart';
import 'package:beebase/data/models/day_count_response.dart';
import 'package:beebase/data/models/hive_inspection_count_response.dart';
import 'package:beebase/data/models/inspection_stats_response.dart';
import 'package:beebase/data/models/overview_response.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary_hive_count.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/day_count.dart';
import 'package:beebase/domain/entity/hive_inspection_count.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';

extension OverviewResponseX on OverviewResponse {
  DashboardOverview toEntity() => DashboardOverview(
    totalApiaries: totalApiaries,
    totalHives: totalHives,
    totalInspections: totalInspections,
    inspectionsLast7Days: inspectionsLast7Days,
    inspectionsThisMonth: inspectionsThisMonth,
    inspectionsThisYear: inspectionsThisYear,
    apiariesWithoutHives: apiariesWithoutHives,
    hivesWithoutInspections: hivesWithoutInspections,
    avgHivesPerApiary: avgHivesPerApiary,
    avgInspectionsPerHive: avgInspectionsPerHive,
    latestInspectionAt: latestInspectionAt,
  );
}

extension ApiaryHiveCountResponseX on ApiaryHiveCountResponse {
  ApiaryHiveCount toEntity() =>
      ApiaryHiveCount(apiaryId: apiaryId, name: name, hiveCount: hiveCount);
}

extension ApiaryStatsResponseX on ApiaryStatsResponse {
  ApiaryStats toEntity() => ApiaryStats(
    totalApiaries: totalApiaries,
    apiariesWithoutHives: apiariesWithoutHives,
    apiaryWithMostHives: apiaryWithMostHives?.toEntity(),
    hiveDistribution: hiveDistribution.map((item) => item.toEntity()).toList(),
  );
}

extension HiveInspectionCountResponseX on HiveInspectionCountResponse {
  HiveInspectionCount toEntity() => HiveInspectionCount(
    hiveId: hiveId,
    hiveName: hiveName,
    apiaryId: apiaryId,
    apiaryName: apiaryName,
    inspectionCount: inspectionCount,
  );
}

extension DayCountResponseX on DayCountResponse {
  DayCount toEntity() => DayCount(date: date, count: count);
}

extension InspectionStatsResponseX on InspectionStatsResponse {
  InspectionStats toEntity() => InspectionStats(
    totalInspections: totalInspections,
    inspectionsLast7Days: inspectionsLast7Days,
    inspectionsThisMonth: inspectionsThisMonth,
    inspectionsThisYear: inspectionsThisYear,
    hiveWithMostInspections: hiveWithMostInspections?.toEntity(),
    latestInspectionAt: latestInspectionAt,
    activityLast30Days: activityLast30Days
        .map((item) => item.toEntity())
        .toList(),
  );
}

extension ActivityItemResponseX on ActivityItemResponse {
  ActivityItem toEntity() => ActivityItem(
    inspectionId: inspectionId,
    inspectedAt: inspectedAt,
    hiveId: hiveId,
    hiveName: hiveName,
    apiaryId: apiaryId,
    apiaryName: apiaryName,
    notes: notes,
  );
}
