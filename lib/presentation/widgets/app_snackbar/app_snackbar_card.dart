import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Visual body of one entry in [AppSnackBarStack]: a floating card, styled
/// after the app's honey/hive palette (see [AppColor]), with a colored
/// accent bar, a message, an optional description, an optional text action,
/// and a close button. Purely presentational — entrance/exit motion and
/// lifetime live in [AppSnackBarStackItem]; this is the one visual surface
/// every [AppSnackBar.show] call renders through, whether it's a one-off
/// toast or a persistent, state-driven banner (see [AppSnackBarEntry.tag]).
///
/// [isLoading] swaps the action/dismiss area for a progress spinner, for
/// entries representing work in flight (e.g. a sync running) where
/// dismissing or acting again wouldn't make sense. [trailing], when given
/// (and [isLoading] is false), replaces that area with arbitrary content
/// instead.
final class AppSnackBarCard extends StatelessWidget {
  const AppSnackBarCard({
    required this.message,
    this.description,
    this.variant = AppSnackBarVariant.neutral,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.isLoading = false,
    this.trailing,
    super.key,
  });

  final String message;
  final String? description;
  final AppSnackBarVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool isLoading;
  final Widget? trailing;

  static const double cardRadius = 14;
  static const double _loadingIndicatorSize = 18;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final spacing = context.spacing;

    final trailingContent = isLoading
        ? const SizedBox(
            width: _loadingIndicatorSize,
            height: _loadingIndicatorSize,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : trailing;

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
        // A Stack-positioned bar (rather than a `Row` child stretched via
        // `IntrinsicHeight`) so the accent's height always just follows
        // whatever height the text content settles on — `IntrinsicHeight`
        // sizing a `Row` that contains an `Expanded` + wrapping `Text` is a
        // known Flutter pitfall that can blow the computed height up to
        // several times the content's actual size once the message needs
        // more than one line (exactly the case for real, sentence-length
        // copy like the offline-sync message).
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: variant.accentColor(colors))),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(message, style: textStyles.body),
                          if (description != null) ...[
                            SizedBox(height: spacing.xs),
                            Text(description!, style: textStyles.body.copyWith(color: colors.text.secondary)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (trailingContent != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      child: trailingContent,
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
          ],
        ),
      ),
    );
  }
}
