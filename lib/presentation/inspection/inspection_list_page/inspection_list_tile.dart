part of '../inspection_list_page.dart';

/// A compact card row — mirrors [_HiveListTile].
final class _InspectionListTile extends StatelessWidget {
  const _InspectionListTile({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasNotes = inspection.notes.isNotEmpty;
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
                decoration: BoxDecoration(color: colors.honey.border, shape: BoxShape.circle),
                child: Icon(Icons.fact_check_outlined, color: colors.brand.primary),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inspection.date.toInspectionDisplayDate(), style: context.textStyles.body),
                    if (hasNotes) ...[
                      SizedBox(height: context.spacing.xs),
                      Text(
                        inspection.notes,
                        style: context.textStyles.label.copyWith(color: colors.text.secondary),
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
    // InspectionDetailsRoute is a root-level route, not nested under this
    // page's own stack, so it must be pushed via the root router. Any
    // edit/delete made there reaches this list via
    // InspectionListRefreshNotifier, so there's nothing to await here.
    context.router.root.push(InspectionDetailsRoute(inspection: inspection));
  }
}
