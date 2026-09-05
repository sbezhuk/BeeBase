part of '../dashboard_cubit.dart';

mixin DashboardEmitter on Cubit<DashboardState> {
  /// Bumped by every authoritative reset — [emitLoad] and [emitRefresh] —
  /// and read (never bumped) once a fetch resolves, so a response that lands
  /// after a newer one already reset the dashboard is discarded instead of
  /// overwriting fresher state with stale data.
  int _generation = 0;

  Future<void> emitLoad(IStatisticsReader statisticsReader, INetworkInfo networkInfo) async {
    if (!await networkInfo.isConnected) {
      emit(const DashboardOffline());
      return;
    }
    emit(const DashboardLoading());
    await _fetchAll(statisticsReader, ++_generation);
  }

  Future<void> emitRefresh(IStatisticsReader statisticsReader, INetworkInfo networkInfo) async {
    if (!await networkInfo.isConnected) {
      emit(const DashboardOffline());
      return;
    }
    final current = state;
    if (current is DashboardLoaded) emit(current.copyWith(isRefreshing: true));
    await _fetchAll(statisticsReader, ++_generation);
  }

  Future<void> _fetchAll(IStatisticsReader statisticsReader, int generation) async {
    final overviewFuture = statisticsReader.getOverview();
    final apiaryStatsFuture = statisticsReader.getApiaryStats();
    final inspectionStatsFuture = statisticsReader.getInspectionStats();
    final activityFuture = statisticsReader.getRecentActivity();

    final overviewResult = await overviewFuture;
    final apiaryStatsResult = await apiaryStatsFuture;
    final inspectionStatsResult = await inspectionStatsFuture;
    final activityResult = await activityFuture;
    if (generation != _generation) return;

    emit(
      DashboardLoaded(
        overview: overviewResult.fold(
          (failure) => SectionError<DashboardOverview>(failure),
          (value) => SectionData<DashboardOverview>(value),
        ),
        apiaryStats: apiaryStatsResult.fold(
          (failure) => SectionError<ApiaryStats>(failure),
          (value) => SectionData<ApiaryStats>(value),
        ),
        inspectionStats: inspectionStatsResult.fold(
          (failure) => SectionError<InspectionStats>(failure),
          (value) => SectionData<InspectionStats>(value),
        ),
        recentActivity: activityResult.fold(
          (failure) => SectionError<List<ActivityItem>>(failure),
          (value) => SectionData<List<ActivityItem>>(value),
        ),
      ),
    );
  }

  Future<void> emitRetryOverview(IStatisticsReader statisticsReader) async {
    final current = state;
    if (current is! DashboardLoaded) return;
    final generation = _generation;
    emit(current.copyWith(overview: const SectionLoading()));

    final result = await statisticsReader.getOverview();
    if (generation != _generation || state is! DashboardLoaded) return;
    emit(
      (state as DashboardLoaded).copyWith(
        overview: result.fold(
          (failure) => SectionError<DashboardOverview>(failure),
          (value) => SectionData<DashboardOverview>(value),
        ),
      ),
    );
  }

  Future<void> emitRetryApiaryStats(IStatisticsReader statisticsReader) async {
    final current = state;
    if (current is! DashboardLoaded) return;
    final generation = _generation;
    emit(current.copyWith(apiaryStats: const SectionLoading()));

    final result = await statisticsReader.getApiaryStats();
    if (generation != _generation || state is! DashboardLoaded) return;
    emit(
      (state as DashboardLoaded).copyWith(
        apiaryStats: result.fold((failure) => SectionError<ApiaryStats>(failure), (value) => SectionData<ApiaryStats>(value)),
      ),
    );
  }

  Future<void> emitRetryInspectionStats(IStatisticsReader statisticsReader) async {
    final current = state;
    if (current is! DashboardLoaded) return;
    final generation = _generation;
    emit(current.copyWith(inspectionStats: const SectionLoading()));

    final result = await statisticsReader.getInspectionStats();
    if (generation != _generation || state is! DashboardLoaded) return;
    emit(
      (state as DashboardLoaded).copyWith(
        inspectionStats: result.fold(
          (failure) => SectionError<InspectionStats>(failure),
          (value) => SectionData<InspectionStats>(value),
        ),
      ),
    );
  }

  Future<void> emitRetryRecentActivity(IStatisticsReader statisticsReader) async {
    final current = state;
    if (current is! DashboardLoaded) return;
    final generation = _generation;
    emit(current.copyWith(recentActivity: const SectionLoading()));

    final result = await statisticsReader.getRecentActivity();
    if (generation != _generation || state is! DashboardLoaded) return;
    emit(
      (state as DashboardLoaded).copyWith(
        recentActivity: result.fold(
          (failure) => SectionError<List<ActivityItem>>(failure),
          (value) => SectionData<List<ActivityItem>>(value),
        ),
      ),
    );
  }
}
