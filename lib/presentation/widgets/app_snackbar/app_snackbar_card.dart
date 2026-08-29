import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Visual body of one toast in [AppSnackBarStack]: a floating card, styled
/// after the app's honey/hive palette (see [AppColor]), with a colored
/// accent bar, a message, an optional text action, and a close button.
/// Purely presentational — entrance/exit motion and lifetime live in
/// [AppSnackBarStackItem]. Also reused directly (outside the toast queue) by
/// persistent, state-driven banners such as `OfflineSyncBanner` — [trailing],
/// when given, replaces the action/dismiss area entirely (e.g. a progress
/// spinner while a sync is in flight, where dismissing wouldn't make sense).
final class AppSnackBarCard extends StatelessWidget {
  const AppSnackBarCard({
    required this.message,
    this.variant = AppSnackBarVariant.neutral,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.trailing,
    super.key,
  });

  final String message;
  final AppSnackBarVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final Widget? trailing;

  static const double cardRadius = 14;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final spacing = context.spacing;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: colors.surface.background,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: colors.honey.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: variant.accentColor(colors)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(message, style: textStyles.body),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  child: trailing,
                )
              else ...[
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!, style: textStyles.action),
                  ),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, color: colors.honey.muted, size: 20),
                  tooltip: 'core.snackbar.dismiss'.tr(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
