part of '../profile_page.dart';

/// Shared list-tile chrome for a single Profile settings row — mirrors
/// `HiveListTile`/`InspectionListTile`'s shape (rounded [Material] +
/// [InkWell], circular icon badge, title/subtitle, trailing content) so
/// Profile's settings rows read as the same component family as every other
/// list tile in the app, instead of the plain label-and-row layout this page
/// used before.
final class _ProfileSettingsTile extends StatelessWidget {
  const _ProfileSettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.iconColor,
    this.iconBackgroundColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  /// Extra content shown before the chevron, e.g. the current language name
  /// or a "Sync now" button. Rows with nothing to show here (change
  /// password) leave it null.
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  /// Override the default brand-colored icon badge — used by the
  /// destructive rows (logout, delete account) to tint the badge and title
  /// with `colors.status.error` instead, so a rare/dangerous row still reads
  /// as clearly different from a common settings row while keeping the same
  /// card chrome as everything else on the page.
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? colors.honey.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? colors.brand.primary,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.body.copyWith(
                        color: titleColor,
                      ),
                    ),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.textStyles.label.copyWith(
                          color: subtitleColor ?? colors.text.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                SizedBox(width: context.spacing.sm),
                trailing,
              ],
              if (showChevron) ...[
                SizedBox(width: context.spacing.xs),
                Icon(Icons.chevron_right, color: colors.text.secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
