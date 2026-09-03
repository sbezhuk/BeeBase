part of '../home_page.dart';

final class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.state});

  final DashboardLoaded state;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.all(context.spacing.md),
      sliver: SliverList.list(
        children: [
          _DashboardOverviewSection(section: state.overview),
          SizedBox(height: context.spacing.md),
          _DashboardApiaryStatsSection(section: state.apiaryStats),
          SizedBox(height: context.spacing.md),
          _DashboardInspectionStatsSection(section: state.inspectionStats),
          SizedBox(height: context.spacing.md),
          _DashboardRecentActivitySection(section: state.recentActivity),
        ],
      ),
    );
  }
}
