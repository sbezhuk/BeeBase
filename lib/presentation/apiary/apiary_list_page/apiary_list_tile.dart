part of '../apiary_list_page.dart';

/// Full-bleed, edge-to-edge tile — no card chrome, no side margins, so the
/// photo placeholder (and eventually a real photo) spans the whole width.
/// Caption info sits below the photo, not overlaid on it.
final class _ApiaryListTile extends StatelessWidget {
  const _ApiaryListTile({required this.apiary, required this.hiveCount, super.key});

  final Apiary apiary;
  final int hiveCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLocation = apiary.location != null && apiary.location!.isNotEmpty;
    return InkWell(
      onTap: () => _openDetails(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocProvider(
            create: (_) => di.get<MediaGalleryCubit>(param1: MediaOwnerType.apiary, param2: apiary.id)..load(),
            child: ApiaryPreviewImage(apiary: apiary, height: 200),
          ),
          Padding(
            padding: EdgeInsets.all(context.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apiary.name, style: context.textStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (apiary.syncStatus != ApiarySyncStatus.synced) ...[
                  SizedBox(height: context.spacing.xs),
                  ApiarySyncBadge(status: apiary.syncStatus),
                ],
                if (hasLocation) ...[
                  SizedBox(height: context.spacing.xs),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: colors.text.secondary),
                      SizedBox(width: context.spacing.xs),
                      Expanded(
                        child: Text(
                          apiary.location!,
                          style: context.textStyles.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: context.spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ApiaryListStat(
                        icon: Icons.hive_outlined,
                        text: hiveCount > 0
                            ? 'apiary.list.hivesCount'.tr(namedArgs: {'count': '$hiveCount'})
                            : 'apiary.list.noHives'.tr(),
                        color: colors.text.secondary,
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _ApiaryListStat(
                          icon: Icons.calendar_today_outlined,
                          text: 'apiary.list.lastVisit'.tr(namedArgs: {'date': apiary.updatedAt.toApiaryDisplayDate()}),
                          color: colors.text.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context) {
    // ApiaryDetailsRoute is a root-level route (a sibling of MainRoute, not
    // nested under this tab), so it must be pushed via the root router —
    // context.router here is scoped to this tab's own stack, which doesn't
    // know this route exists. Any edit/delete made there reaches the list
    // via ApiaryListRefreshNotifier, so there's nothing to await here.
    context.router.root.push(ApiaryDetailsRoute(apiary: apiary));
  }
}
