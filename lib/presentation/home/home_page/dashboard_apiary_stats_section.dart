part of '../home_page.dart';

final class _DashboardApiaryStatsSection extends StatelessWidget {
  const _DashboardApiaryStatsSection({required this.section});

  final DashboardSection<ApiaryStats> section;

  Future<void> _openApiary(BuildContext context, String apiaryId) {
    final cubit = context.read<DashboardCubit>();
    return _fetchThenNavigate<Apiary>(
      context: context,
      request: () => cubit.fetchApiary(apiaryId),
      onSuccess: (apiary) =>
          context.router.root.push(ApiaryDetailsRoute(apiary: apiary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return DashboardSectionCard(
      title: 'dashboard.apiary_stats.title'.tr(),
      child: _DashboardSectionSwitcher<ApiaryStats>(
        section: section,
        onRetry: cubit.retryApiaryStats,
        builder: (context, stats) {
          if (stats.totalApiaries == 0) {
            return _DashboardEmptyView(
              icon: Icons.hive_outlined,
              title: 'dashboard.apiary_stats.empty_title'.tr(),
              subtitle: 'dashboard.apiary_stats.empty_subtitle'.tr(),
            );
          }
          final mostHives = stats.apiaryWithMostHives;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardStatTile(
                label: 'dashboard.apiary_stats.total_apiaries'.tr(),
                value: '${stats.totalApiaries}',
              ),
              DashboardStatTile(
                label: 'dashboard.apiary_stats.apiaries_without_hives'.tr(),
                value: '${stats.apiariesWithoutHives}',
              ),
              if (mostHives != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                  child: _DashboardTappableTile(
                    onTap: () => _openApiary(context, mostHives.apiaryId),
                    child: DashboardStatTile(
                      label: 'dashboard.apiary_stats.most_hives'.tr(),
                      value: '${mostHives.name} (${mostHives.hiveCount})',
                    ),
                  ),
                ),
              if (stats.hiveDistribution.isNotEmpty) ...[
                SizedBox(height: context.spacing.md),
                Text(
                  'dashboard.apiary_stats.distribution_title'.tr(),
                  style: context.textStyles.label,
                ),
                SizedBox(height: context.spacing.sm),
                HiveDistributionChart(
                  data: stats.hiveDistribution,
                  onBarTap: (apiary) => _openApiary(context, apiary.apiaryId),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
