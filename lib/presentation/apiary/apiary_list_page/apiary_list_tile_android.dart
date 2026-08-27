part of '../apiary_list_page.dart';

final class _AndroidApiaryListTile extends StatelessWidget {
  const _AndroidApiaryListTile({required this.apiary, required this.onTap});

  final Apiary apiary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLocation = apiary.location != null && apiary.location!.isNotEmpty;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.md),
          child: Row(
            children: [
              const ApiaryHexagonBadge(),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apiary.name, style: context.textStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (hasLocation) ...[
                      SizedBox(height: context.spacing.xs),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 14, color: colors.textSecondary),
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
}
