import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/statistics_data_source.dart';
import 'package:beebase/data/models/extensions/statistics_extension.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/domain/repositories/statistics_reader.dart';
import 'package:beebase/utils/either.dart';

final class StatisticsRepositoryImpl extends Repository
    implements IStatisticsReader {
  StatisticsRepositoryImpl({required this.dataSource});

  final IStatisticsDataSource dataSource;

  @override
  Future<Either<Failure, DashboardOverview>> getOverview() {
    return on(() async => (await dataSource.getOverview()).toEntity());
  }

  @override
  Future<Either<Failure, ApiaryStats>> getApiaryStats() {
    return on(() async => (await dataSource.getApiaryStats()).toEntity());
  }

  @override
  Future<Either<Failure, InspectionStats>> getInspectionStats() {
    return on(() async => (await dataSource.getInspectionStats()).toEntity());
  }

  @override
  Future<Either<Failure, List<ActivityItem>>> getRecentActivity({
    int limit = 10,
  }) {
    return on(() async {
      final response = await dataSource.getActivity(limit: limit);
      return response.items.map((item) => item.toEntity()).toList();
    });
  }
}
