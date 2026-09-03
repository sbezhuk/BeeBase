part of '../home_page.dart';

final class _DashboardOverviewSection extends StatelessWidget {
  const _DashboardOverviewSection({required this.section});

  final DashboardSection<DashboardOverview> section;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return DashboardSectionCard(
      title: 'dashboard.overview.title'.tr(),
      child: _DashboardSectionSwitcher<DashboardOverview>(
        section: section,
        onRetry: cubit.retryOverview,
        builder: (context, overview) {
          if (overview.totalApiaries == 0 && overview.totalHives == 0) {
            return _DashboardEmptyView(
              icon: Icons.query_stats,
              title: 'dashboard.overview.empty_title'.tr(),
              subtitle: 'dashboard.overview.empty_subtitle'.tr(),
            );
          }
          final dateFormat = DateFormat.yMMMd();
          return Column(
            children: [
              DashboardStatTile(
                label: 'dashboard.overview.total_apiaries'.tr(),
                value: '${overview.totalApiaries}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.total_hives'.tr(),
                value: '${overview.totalHives}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.total_inspections'.tr(),
                value: '${overview.totalInspections}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.last_7_days'.tr(),
                value: '${overview.inspectionsLast7Days}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.this_month'.tr(),
                value: '${overview.inspectionsThisMonth}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.this_year'.tr(),
                value: '${overview.inspectionsThisYear}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.apiaries_without_hives'.tr(),
                value: '${overview.apiariesWithoutHives}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.hives_without_inspections'.tr(),
                value: '${overview.hivesWithoutInspections}',
              ),
              DashboardStatTile(
                label: 'dashboard.overview.avg_hives_per_apiary'.tr(),
                value: overview.avgHivesPerApiary.toStringAsFixed(1),
              ),
              DashboardStatTile(
                label: 'dashboard.overview.avg_inspections_per_hive'.tr(),
                value: overview.avgInspectionsPerHive.toStringAsFixed(1),
              ),
              DashboardStatTile(
                label: 'dashboard.overview.latest_inspection'.tr(),
                value: overview.latestInspectionAt == null
                    ? '—'
                    : dateFormat.format(overview.latestInspectionAt!.toLocal()),
              ),
            ],
          );
        },
      ),
    );
  }
}
