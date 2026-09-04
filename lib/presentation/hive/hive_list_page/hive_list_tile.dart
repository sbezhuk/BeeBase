part of '../hive_list_page.dart';

/// A compact card row — unlike [_ApiaryListTile], a hive has no photo/map
/// preview, so the tile is a single-line leading-icon row instead of a
/// full-bleed image tile.
final class _HiveListTile extends StatelessWidget {
  const _HiveListTile({required this.hive});

  final Hive hive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDescription = hive.notes != null && hive.notes!.isNotEmpty;
    return Material(
      color: colors.surface.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(context),
        child: Padding(
          padding: EdgeInsets.all(context.spacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.honey.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hive_outlined, color: colors.brand.primary),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hive.name,
                      style: context.textStyles.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasDescription) ...[
                      SizedBox(height: context.spacing.xs),
                      Text(
                        hive.notes!,
                        style: context.textStyles.label.copyWith(
                          color: colors.text.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Icon(Icons.chevron_right, color: colors.text.secondary),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    // HiveDetailsRoute is a root-level route, not nested under this page's
    // own stack, so it must be pushed via the root router. Any edit/delete
    // made there reaches this list via HiveListRefreshNotifier, so there's
    // nothing to await here.
    context.router.root.push(HiveDetailsRoute(hive: hive));
  }
}
