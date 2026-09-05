import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/statistics_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/presentation/home/cubit/dashboard_cubit/dashboard_cubit.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStatisticsReader extends Mock implements IStatisticsReader {}

class MockApiaryReader extends Mock implements IApiaryReader {}

class MockHiveReader extends Mock implements IHiveReader {}

class MockInspectionReader extends Mock implements IInspectionReader {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

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

const _apiaryStats = ApiaryStats(totalApiaries: 3, apiariesWithoutHives: 1, hiveDistribution: []);

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
  late MockNetworkInfo networkInfo;
  late StreamController<bool> connectivityController;
  late ApiaryListRefreshNotifier apiaryRefreshNotifier;
  late HiveListRefreshNotifier hiveRefreshNotifier;
  late InspectionListRefreshNotifier inspectionRefreshNotifier;

  DashboardCubit buildCubit() {
    return DashboardCubit(
      statisticsReader: statisticsReader,
      apiaryReader: apiaryReader,
      hiveReader: hiveReader,
      inspectionReader: inspectionReader,
      networkInfo: networkInfo,
      apiaryRefreshNotifier: apiaryRefreshNotifier,
      hiveRefreshNotifier: hiveRefreshNotifier,
      inspectionRefreshNotifier: inspectionRefreshNotifier,
    );
  }

  void stubAllSuccess() {
    when(() => statisticsReader.getOverview()).thenAnswer((_) async => const Right(_overview));
    when(() => statisticsReader.getApiaryStats()).thenAnswer((_) async => const Right(_apiaryStats));
    when(() => statisticsReader.getInspectionStats()).thenAnswer((_) async => const Right(_inspectionStats));
    when(() => statisticsReader.getRecentActivity()).thenAnswer((_) async => const Right(_activity));
  }

  setUp(() {
    statisticsReader = MockStatisticsReader();
    apiaryReader = MockApiaryReader();
    hiveReader = MockHiveReader();
    inspectionReader = MockInspectionReader();
    networkInfo = MockNetworkInfo();
    connectivityController = StreamController<bool>.broadcast();
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(() => networkInfo.onConnectivityChanged).thenAnswer((_) => connectivityController.stream);
    apiaryRefreshNotifier = ApiaryListRefreshNotifier();
    hiveRefreshNotifier = HiveListRefreshNotifier();
    inspectionRefreshNotifier = InspectionListRefreshNotifier();
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
          .having((state) => state.overview, 'overview', const SectionData(_overview))
          .having((state) => state.apiaryStats, 'apiaryStats', const SectionData(_apiaryStats))
          .having((state) => state.inspectionStats, 'inspectionStats', const SectionData(_inspectionStats))
          .having((state) => (state.recentActivity as SectionData<List<ActivityItem>>).value, 'recentActivity', _activity),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'loadDashboard emits DashboardOffline and makes no request when offline',
    build: () {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      stubAllSuccess();
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
    'refresh emits DashboardOffline and makes no request when offline',
    build: () {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      stubAllSuccess();
      return buildCubit();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [const DashboardOffline()],
    verify: (_) {
      verifyNever(() => statisticsReader.getOverview());
    },
  );

  blocTest<DashboardCubit, DashboardState>(
    'losing connectivity while Loaded switches to DashboardOffline',
    build: () {
      stubAllSuccess();
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadDashboard();
      connectivityController.add(false);
      await Future<void>.delayed(Duration.zero);
    },
    skip: 1,
    expect: () => [isA<DashboardLoaded>(), const DashboardOffline()],
  );

  blocTest<DashboardCubit, DashboardState>(
    'regaining connectivity does not auto-reload; retry does',
    build: () {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadDashboard();
      connectivityController.add(true);
      await Future<void>.delayed(Duration.zero);
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      stubAllSuccess();
      await cubit.loadDashboard();
    },
    expect: () => [const DashboardOffline(), const DashboardLoading(), isA<DashboardLoaded>()],
  );

  blocTest<DashboardCubit, DashboardState>(
    'a single section failing does not block the other sections (per-section isolation)',
    build: () {
      when(() => statisticsReader.getOverview()).thenAnswer((_) async => const Right(_overview));
      when(
        () => statisticsReader.getApiaryStats(),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'internal_error', message: 'boom')));
      when(() => statisticsReader.getInspectionStats()).thenAnswer((_) async => const Right(_inspectionStats));
      when(() => statisticsReader.getRecentActivity()).thenAnswer((_) async => const Right(_activity));
      return buildCubit();
    },
    act: (cubit) => cubit.loadDashboard(),
    expect: () => [
      const DashboardLoading(),
      isA<DashboardLoaded>()
          .having((state) => state.overview, 'overview', const SectionData(_overview))
          .having((state) => state.apiaryStats, 'apiaryStats', isA<SectionError<ApiaryStats>>())
          .having((state) => state.inspectionStats, 'inspectionStats', const SectionData(_inspectionStats)),
    ],
  );

  test('a response from a superseded load is discarded once it finally resolves', () async {
    var overviewCallCount = 0;
    final firstOverviewCompleter = Completer<Either<Failure, DashboardOverview>>();
    when(() => statisticsReader.getOverview()).thenAnswer((_) {
      overviewCallCount++;
      return overviewCallCount == 1 ? firstOverviewCompleter.future : Future.value(const Right(_overview));
    });
    when(() => statisticsReader.getApiaryStats()).thenAnswer((_) async => const Right(_apiaryStats));
    when(() => statisticsReader.getInspectionStats()).thenAnswer((_) async => const Right(_inspectionStats));
    when(() => statisticsReader.getRecentActivity()).thenAnswer((_) async => const Right(_activity));

    final cubit = buildCubit();
    unawaited(cubit.loadDashboard()); // first load — stuck awaiting firstOverviewCompleter
    await Future<void>.delayed(Duration.zero);
    await cubit.loadDashboard(); // second load — supersedes the first, resolves immediately

    final stateAfterSecondLoad = cubit.state;
    expect(stateAfterSecondLoad, isA<DashboardLoaded>());

    firstOverviewCompleter.complete(const Right(_overview));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, same(stateAfterSecondLoad));
    await cubit.close();
  });

  test('apiaryRefreshNotifier signalling a change while Loaded refetches only overview and apiary stats', () async {
    stubAllSuccess();
    final cubit = buildCubit();
    await cubit.loadDashboard();
    clearInteractions(statisticsReader);

    const updatedApiaryStats = ApiaryStats(totalApiaries: 4, apiariesWithoutHives: 0, hiveDistribution: []);
    when(() => statisticsReader.getApiaryStats()).thenAnswer((_) async => const Right(updatedApiaryStats));

    apiaryRefreshNotifier.notify();
    await Future<void>.delayed(Duration.zero);

    verify(() => statisticsReader.getOverview()).called(1);
    verify(() => statisticsReader.getApiaryStats()).called(1);
    verifyNever(() => statisticsReader.getInspectionStats());
    verifyNever(() => statisticsReader.getRecentActivity());
    expect((cubit.state as DashboardLoaded).apiaryStats, const SectionData(updatedApiaryStats));

    await cubit.close();
  });

  test('hiveRefreshNotifier signalling a change while Loaded refetches only overview and apiary stats', () async {
    stubAllSuccess();
    final cubit = buildCubit();
    await cubit.loadDashboard();
    clearInteractions(statisticsReader);

    hiveRefreshNotifier.notify();
    await Future<void>.delayed(Duration.zero);

    verify(() => statisticsReader.getOverview()).called(1);
    verify(() => statisticsReader.getApiaryStats()).called(1);
    verifyNever(() => statisticsReader.getInspectionStats());
    verifyNever(() => statisticsReader.getRecentActivity());

    await cubit.close();
  });

  test(
    'inspectionRefreshNotifier signalling a change while Loaded refetches only overview, inspection stats, and recent activity',
    () async {
      stubAllSuccess();
      final cubit = buildCubit();
      await cubit.loadDashboard();
      clearInteractions(statisticsReader);

      const updatedInspectionStats = InspectionStats(
        totalInspections: 43,
        inspectionsLast7Days: 3,
        inspectionsThisMonth: 6,
        inspectionsThisYear: 21,
        activityLast30Days: [],
      );
      when(() => statisticsReader.getInspectionStats()).thenAnswer((_) async => const Right(updatedInspectionStats));

      inspectionRefreshNotifier.notify();
      await Future<void>.delayed(Duration.zero);

      verify(() => statisticsReader.getOverview()).called(1);
      verify(() => statisticsReader.getInspectionStats()).called(1);
      verify(() => statisticsReader.getRecentActivity()).called(1);
      verifyNever(() => statisticsReader.getApiaryStats());
      expect((cubit.state as DashboardLoaded).inspectionStats, const SectionData(updatedInspectionStats));

      await cubit.close();
    },
  );

  test('a refresh notifier signalling a change before the dashboard has loaded is a no-op', () async {
    stubAllSuccess();
    final cubit = buildCubit();

    apiaryRefreshNotifier.notify();
    hiveRefreshNotifier.notify();
    inspectionRefreshNotifier.notify();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const DashboardLoading());
    verifyNever(() => statisticsReader.getOverview());
    verifyNever(() => statisticsReader.getApiaryStats());
    verifyNever(() => statisticsReader.getInspectionStats());
    verifyNever(() => statisticsReader.getRecentActivity());

    await cubit.close();
  });
}
