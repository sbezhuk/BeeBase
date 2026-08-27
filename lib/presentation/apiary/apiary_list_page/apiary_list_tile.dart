part of '../apiary_list_page.dart';

final class _ApiaryListTile extends StatelessWidget {
  const _ApiaryListTile({required this.apiary});

  final Apiary apiary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.md),
          child: Row(
            children: [
              Icon(Icons.hive, color: colors.primary),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apiary.name, style: context.textStyles.body),
                    if (apiary.location != null &&
                        apiary.location!.isNotEmpty) ...[
                      SizedBox(height: context.spacing.xs),
                      Text(apiary.location!, style: context.textStyles.label),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
        ),
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
