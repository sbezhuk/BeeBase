part of '../home_page.dart';

final class _DashboardRecentActivitySection extends StatelessWidget {
  const _DashboardRecentActivitySection({required this.section});

  final DashboardSection<List<ActivityItem>> section;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return DashboardSectionCard(
      title: 'dashboard.recent_activity.title'.tr(),
      child: _DashboardSectionSwitcher<List<ActivityItem>>(
        section: section,
        onRetry: cubit.retryRecentActivity,
        builder: (context, items) {
          if (items.isEmpty) {
            return _DashboardEmptyView(
              icon: Icons.history,
              title: 'dashboard.recent_activity.empty_title'.tr(),
              subtitle: 'dashboard.recent_activity.empty_subtitle'.tr(),
            );
          }
          return Column(
            children: [
              for (final item in items)
                Padding(
                  padding: EdgeInsets.only(bottom: context.spacing.sm),
                  child: _DashboardActivityTile(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

final class _DashboardActivityTile extends StatelessWidget {
  const _DashboardActivityTile({required this.item});

  final ActivityItem item;

  Future<void> _open(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return _fetchThenNavigate<Inspection>(
      context: context,
      request: () =>
          cubit.fetchInspection(hiveId: item.hiveId, id: item.inspectionId),
      onSuccess: (inspection) => context.router.root.push(
        InspectionDetailsRoute(inspection: inspection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _DashboardTappableTile(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.inspectedAt.toLocal().toDashboardActivityDisplayDate(),
            style: context.textStyles.label.copyWith(color: colors.honey.muted),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            '${item.hiveName} · ${item.apiaryName}',
            style: context.textStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.notes.isNotEmpty) ...[
            SizedBox(height: context.spacing.xs),
            Text(
              item.notes,
              style: context.textStyles.body.copyWith(
                color: colors.text.secondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
