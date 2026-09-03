import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/statistics_data_source.dart';
import 'package:beebase/data/models/activity_item_response.dart';
import 'package:beebase/data/models/activity_response.dart';
import 'package:beebase/data/models/apiary_hive_count_response.dart';
import 'package:beebase/data/models/apiary_stats_response.dart';
import 'package:beebase/data/models/day_count_response.dart';
import 'package:beebase/data/models/hive_inspection_count_response.dart';
import 'package:beebase/data/models/inspection_stats_response.dart';
import 'package:beebase/data/models/overview_response.dart';
import 'package:beebase/data/repositories/statistics_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStatisticsDataSource extends Mock implements IStatisticsDataSource {}

void main() {
  late MockStatisticsDataSource dataSource;
  late StatisticsRepositoryImpl repository;

  setUp(() {
    dataSource = MockStatisticsDataSource();
    repository = StatisticsRepositoryImpl(dataSource: dataSource);
  });

  group('getOverview', () {
    test('returns the mapped overview on success', () async {
      when(() => dataSource.getOverview()).thenAnswer(
        (_) async => const OverviewResponse(
          totalApiaries: 3,
          totalHives: 10,
          totalInspections: 42,
          inspectionsLast7Days: 2,
          inspectionsThisMonth: 5,
          inspectionsThisYear: 20,
          apiariesWithoutHives: 1,
          hivesWithoutInspections: 2,
          avgHivesPerApiary: 3.33,
          avgInspectionsPerHive: 4.2,
        ),
      );

      final result = await repository.getOverview();

      result.fold(
        (_) => fail('expected Right'),
        (overview) => expect(overview.totalApiaries, 3),
      );
    });

    test('returns a ServerFailure when the data source throws', () async {
      when(() => dataSource.getOverview()).thenThrow(
        const ServerException(
          statusCode: 500,
          code: 'internal_error',
          message: 'boom',
        ),
      );

      final result = await repository.getOverview();

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getApiaryStats', () {
    test('returns the mapped apiary stats on success', () async {
      when(() => dataSource.getApiaryStats()).thenAnswer(
        (_) async => const ApiaryStatsResponse(
          totalApiaries: 2,
          apiariesWithoutHives: 0,
          apiaryWithMostHives: ApiaryHiveCountResponse(
            apiaryId: 'apiary-1',
            name: 'Back Garden',
            hiveCount: 6,
          ),
          hiveDistribution: [
            ApiaryHiveCountResponse(
              apiaryId: 'apiary-1',
              name: 'Back Garden',
              hiveCount: 6,
            ),
            ApiaryHiveCountResponse(
              apiaryId: 'apiary-2',
              name: 'North Field',
              hiveCount: 4,
            ),
          ],
        ),
      );

      final result = await repository.getApiaryStats();

      result.fold((_) => fail('expected Right'), (stats) {
        expect(stats.totalApiaries, 2);
        expect(stats.apiaryWithMostHives?.apiaryId, 'apiary-1');
        expect(stats.hiveDistribution, hasLength(2));
      });
    });
  });

  group('getInspectionStats', () {
    test('returns the mapped inspection stats on success', () async {
      when(() => dataSource.getInspectionStats()).thenAnswer(
        (_) async => InspectionStatsResponse(
          totalInspections: 42,
          inspectionsLast7Days: 2,
          inspectionsThisMonth: 5,
          inspectionsThisYear: 20,
          hiveWithMostInspections: const HiveInspectionCountResponse(
            hiveId: 'hive-1',
            hiveName: 'Hive #1',
            apiaryId: 'apiary-1',
            apiaryName: 'Back Garden',
            inspectionCount: 10,
          ),
          latestInspectionAt: DateTime(2026, 3, 15),
          activityLast30Days: const [
            DayCountResponse(date: '2026-03-15', count: 3),
          ],
        ),
      );

      final result = await repository.getInspectionStats();

      result.fold((_) => fail('expected Right'), (stats) {
        expect(stats.totalInspections, 42);
        expect(stats.hiveWithMostInspections?.hiveId, 'hive-1');
        expect(stats.activityLast30Days, hasLength(1));
      });
    });
  });

  group('getRecentActivity', () {
    test('returns the mapped activity items on success', () async {
      when(() => dataSource.getActivity(limit: 5)).thenAnswer(
        (_) async => ActivityResponse(
          items: [
            ActivityItemResponse(
              inspectionId: 'inspection-1',
              inspectedAt: DateTime(2026, 3, 15),
              hiveId: 'hive-1',
              hiveName: 'Hive #1',
              apiaryId: 'apiary-1',
              apiaryName: 'Back Garden',
              notes: 'Looking healthy',
            ),
          ],
        ),
      );

      final result = await repository.getRecentActivity(limit: 5);

      result.fold((_) => fail('expected Right'), (items) {
        expect(items, hasLength(1));
        expect(items.first.inspectionId, 'inspection-1');
      });
    });

    test('returns a ServerFailure when the data source throws', () async {
      when(() => dataSource.getActivity(limit: 10)).thenThrow(
        const ServerException(
          statusCode: 400,
          code: 'validation_error',
          message: 'invalid limit',
        ),
      );

      final result = await repository.getRecentActivity();

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
