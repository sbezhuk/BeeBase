part of '../home_page.dart';

final class _DashboardInspectionStatsSection extends StatelessWidget {
  const _DashboardInspectionStatsSection({required this.section});

  final DashboardSection<InspectionStats> section;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return DashboardSectionCard(
      title: 'dashboard.inspection_stats.title'.tr(),
      child: _DashboardSectionSwitcher<InspectionStats>(
        section: section,
        onRetry: cubit.retryInspectionStats,
        builder: (context, stats) {
          if (stats.totalInspections == 0) {
            return _DashboardEmptyView(
              icon: Icons.fact_check_outlined,
              title: 'dashboard.inspection_stats.empty_title'.tr(),
              subtitle: 'dashboard.inspection_stats.empty_subtitle'.tr(),
            );
          }
          final mostInspections = stats.hiveWithMostInspections;
          final dateFormat = DateFormat.yMMMd();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardStatTile(
                label: 'dashboard.inspection_stats.total_inspections'.tr(),
                value: '${stats.totalInspections}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.last_7_days'.tr(),
                value: '${stats.inspectionsLast7Days}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.this_month'.tr(),
                value: '${stats.inspectionsThisMonth}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.this_year'.tr(),
                value: '${stats.inspectionsThisYear}',
              ),
              DashboardStatTile(
                label: 'dashboard.inspection_stats.latest_inspection'.tr(),
                value: stats.latestInspectionAt == null
                    ? '—'
                    : dateFormat.format(stats.latestInspectionAt!.toLocal()),
              ),
              if (mostInspections != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                  child: _DashboardTappableTile(
                    onTap: () async => _fetchThenNavigate<Hive>(
                      context: context,
                      request: () => cubit.fetchHive(mostInspections.hiveId),
                      onSuccess: (hive) => context.router.root.push(
                        HiveDetailsRoute(hive: hive),
                      ),
                    ),
                    child: DashboardStatTile(
                      label: 'dashboard.inspection_stats.most_inspections'.tr(),
                      value:
                          '${mostInspections.hiveName} (${mostInspections.inspectionCount})',
                    ),
                  ),
                ),
              if (stats.activityLast30Days.isNotEmpty) ...[
                SizedBox(height: context.spacing.md),
                Text(
                  'dashboard.inspection_stats.activity_title'.tr(),
                  style: context.textStyles.label,
                ),
                SizedBox(height: context.spacing.sm),
                InspectionActivityChart(data: stats.activityLast30Days),
              ],
            ],
          );
        },
      ),
    );
  }
}
