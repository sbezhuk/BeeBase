import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IStatisticsReader {
  Future<Either<Failure, DashboardOverview>> getOverview();

  Future<Either<Failure, ApiaryStats>> getApiaryStats();

  Future<Either<Failure, InspectionStats>> getInspectionStats();

  Future<Either<Failure, List<ActivityItem>>> getRecentActivity({
    int limit = 10,
  });
}
