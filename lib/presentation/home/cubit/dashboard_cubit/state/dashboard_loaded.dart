part of '../dashboard_cubit.dart';

final class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.overview,
    required this.apiaryStats,
    required this.inspectionStats,
    required this.recentActivity,
    this.isRefreshing = false,
  });

  final DashboardSection<DashboardOverview> overview;
  final DashboardSection<ApiaryStats> apiaryStats;
  final DashboardSection<InspectionStats> inspectionStats;
  final DashboardSection<List<ActivityItem>> recentActivity;

  /// True while a pull-to-refresh is in flight — drives `LoadingOverlay` so
  /// the refetch is visible while the previously loaded sections stay on
  /// screen underneath it.
  final bool isRefreshing;

  DashboardLoaded copyWith({
    DashboardSection<DashboardOverview>? overview,
    DashboardSection<ApiaryStats>? apiaryStats,
    DashboardSection<InspectionStats>? inspectionStats,
    DashboardSection<List<ActivityItem>>? recentActivity,
    bool? isRefreshing,
  }) {
    return DashboardLoaded(
      overview: overview ?? this.overview,
      apiaryStats: apiaryStats ?? this.apiaryStats,
      inspectionStats: inspectionStats ?? this.inspectionStats,
      recentActivity: recentActivity ?? this.recentActivity,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardLoaded &&
          other.overview == overview &&
          other.apiaryStats == apiaryStats &&
          other.inspectionStats == inspectionStats &&
          other.recentActivity == recentActivity &&
          other.isRefreshing == isRefreshing);

  @override
  int get hashCode => Object.hash(
    overview,
    apiaryStats,
    inspectionStats,
    recentActivity,
    isRefreshing,
  );
}
