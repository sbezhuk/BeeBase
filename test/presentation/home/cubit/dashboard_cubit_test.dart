import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/statistics_reader.dart';
import 'package:beebase/presentation/home/cubit/dashboard_cubit/dashboard_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStatisticsReader extends Mock implements IStatisticsReader {}

class MockApiaryReader extends Mock implements IApiaryReader {}

class MockHiveReader extends Mock implements IHiveReader {}

class MockInspectionReader extends Mock implements IInspectionReader {}

class MockConnectivityService extends Mock implements IConnectivityService {}

const _overview = DashboardOverview(
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
);

const _apiaryStats = ApiaryStats(
  totalApiaries: 3,
  apiariesWithoutHives: 1,
  hiveDistribution: [],
);

const _inspectionStats = InspectionStats(
  totalInspections: 42,
  inspectionsLast7Days: 2,
  inspectionsThisMonth: 5,
  inspectionsThisYear: 20,
  activityLast30Days: [],
);

const _activity = <ActivityItem>[];

void main() {
  late MockStatisticsReader statisticsReader;
  late MockApiaryReader apiaryReader;
  late MockHiveReader hiveReader;
  late MockInspectionReader inspectionReader;
  late MockConnectivityService connectivity;
  late StreamController<bool> connectivityController;

  DashboardCubit buildCubit() {
    return DashboardCubit(
      statisticsReader: statisticsReader,
      apiaryReader: apiaryReader,
      hiveReader: hiveReader,
      inspectionReader: inspectionReader,
      connectivity: connectivity,
    );
  }

  void stubAllSuccess() {
    when(
      () => statisticsReader.getOverview(),
    ).thenAnswer((_) async => const Right(_overview));
    when(
      () => statisticsReader.getApiaryStats(),
    ).thenAnswer((_) async => const Right(_apiaryStats));
    when(
      () => statisticsReader.getInspectionStats(),
    ).thenAnswer((_) async => const Right(_inspectionStats));
    when(
      () => statisticsReader.getRecentActivity(),
    ).thenAnswer((_) async => const Right(_activity));
  }

  setUp(() {
    statisticsReader = MockStatisticsReader();
    apiaryReader = MockApiaryReader();
    hiveReader = MockHiveReader();
    inspectionReader = MockInspectionReader();
    connectivity = MockConnectivityService();
    connectivityController = StreamController<bool>.broadcast();
    when(
      () => connectivity.status,
    ).thenAnswer((_) => connectivityController.stream);
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
  });

  tearDown(() => connectivityController.close());

  blocTest<DashboardCubit, DashboardState>(
    'loadDashboard emits Loading then Loaded with every section as data, when online',
    build: () {
      stubAllSuccess();
      return buildCubit();
    },
    act: (cubit) => cubit.loadDashboard(),
    expect: () => [
      const DashboardLoading(),
      isA<DashboardLoaded>()
          .having(
            (state) => state.overview,
            'overview',
            const SectionData(_overview),
          )
          .having(
            (state) => state.apiaryStats,
            'apiaryStats',
            const SectionData(_apiaryStats),
          )
          .having(
            (state) => state.inspectionStats,
            'inspectionStats',
            const SectionData(_inspectionStats),
          )
          .having(
            (state) =>
                (state.recentActivity as SectionData<List<ActivityItem>>).value,
            'recentActivity',
            _activity,
          ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'loadDashboard emits Offline directly when there is no connectivity, without calling any reader',
    build: () {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      return buildCubit();
    },
    act: (cubit) => cubit.loadDashboard(),
    expect: () => [const DashboardOffline()],
    verify: (_) {
      verifyNever(() => statisticsReader.getOverview());
      verifyNever(() => statisticsReader.getApiaryStats());
      verifyNever(() => statisticsReader.getInspectionStats());
      verifyNever(() => statisticsReader.getRecentActivity());
    },
  );

  blocTest<DashboardCubit, DashboardState>(
    'a single section failing does not block the other sections (per-section isolation)',
    build: () {
      when(
        () => statisticsReader.getOverview(),
      ).thenAnswer((_) async => const Right(_overview));
      when(() => statisticsReader.getApiaryStats()).thenAnswer(
        (_) async =>
            Left(ServerFailure(code: 'internal_error', message: 'boom')),
      );
      when(
        () => statisticsReader.getInspectionStats(),
      ).thenAnswer((_) async => const Right(_inspectionStats));
      when(
        () => statisticsReader.getRecentActivity(),
      ).thenAnswer((_) async => const Right(_activity));
      return buildCubit();
    },
    act: (cubit) => cubit.loadDashboard(),
    expect: () => [
      const DashboardLoading(),
      isA<DashboardLoaded>()
          .having(
            (state) => state.overview,
            'overview',
            const SectionData(_overview),
          )
          .having(
            (state) => state.apiaryStats,
            'apiaryStats',
            isA<SectionError<ApiaryStats>>(),
          )
          .having(
            (state) => state.inspectionStats,
            'inspectionStats',
            const SectionData(_inspectionStats),
          ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'refresh re-checks connectivity and switches to Offline if it dropped since the page opened',
    build: () {
      stubAllSuccess();
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadDashboard();
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      await cubit.refresh();
    },
    skip: 2,
    expect: () => [const DashboardOffline()],
  );

  blocTest<DashboardCubit, DashboardState>(
    'a connectivity-status drop while Loaded switches to the offline state',
    build: () {
      stubAllSuccess();
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadDashboard();
      connectivityController.add(false);
      await Future<void>.delayed(Duration.zero);
    },
    skip: 2,
    expect: () => [const DashboardOffline()],
  );

  test(
    'a response from a superseded load is discarded once it finally resolves',
    () async {
      var overviewCallCount = 0;
      final firstOverviewCompleter =
          Completer<Either<Failure, DashboardOverview>>();
      when(() => statisticsReader.getOverview()).thenAnswer((_) {
        overviewCallCount++;
        return overviewCallCount == 1
            ? firstOverviewCompleter.future
            : Future.value(const Right(_overview));
      });
      when(
        () => statisticsReader.getApiaryStats(),
      ).thenAnswer((_) async => const Right(_apiaryStats));
      when(
        () => statisticsReader.getInspectionStats(),
      ).thenAnswer((_) async => const Right(_inspectionStats));
      when(
        () => statisticsReader.getRecentActivity(),
      ).thenAnswer((_) async => const Right(_activity));

      final cubit = buildCubit();
      unawaited(
        cubit.loadDashboard(),
      ); // first load — stuck awaiting firstOverviewCompleter
      await Future<void>.delayed(Duration.zero);
      await cubit
          .loadDashboard(); // second load — supersedes the first, resolves immediately

      final stateAfterSecondLoad = cubit.state;
      expect(stateAfterSecondLoad, isA<DashboardLoaded>());

      firstOverviewCompleter.complete(const Right(_overview));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, same(stateAfterSecondLoad));
      await cubit.close();
    },
  );
}
