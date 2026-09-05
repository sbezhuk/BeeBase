import 'package:beebase/presentation/widgets/app_bottom_sheet/app_bottom_sheet.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

/// Shows a [ConfirmationSheet] as a modal bottom sheet, matching the app's
/// honey/hive palette. Used both for a "are you sure?" step before a
/// consequential action (e.g. deleting an apiary — pass [cancelLabel] and
/// [onConfirm]) and for a single-action, "must acknowledge" info notice
/// (e.g. "can't edit this offline" — omit [cancelLabel], which renders just
/// the one action button). Reused instead of a plain [AlertDialog]/Cupertino
/// alert for the latter case too, since a modal bottom sheet already gives
/// every caller a native-feeling, on-brand, opaque presentation without
/// needing separate Material/Cupertino styling per platform.
Future<void> showConfirmationSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  VoidCallback? onConfirm,
  IconData icon = Icons.warning_amber_rounded,
  bool isDestructive = true,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (context) => ConfirmationSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      icon: icon,
      isDestructive: isDestructive,
    ),
  );
}

/// Content of a themed bottom sheet: an icon, a title and message, then a
/// full-width primary action button — plus a secondary (cancel) button when
/// [cancelLabel] is given. With no [cancelLabel], this reads as a single-
/// action info notice rather than a confirm/cancel prompt. Built on
/// [AppBottomSheetCard]/[AppSheetButton] — the same chrome the date picker
/// uses — so every bottom sheet in the app reads as one component family.
final class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.icon = Icons.warning_amber_rounded,
    this.isDestructive = true,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final IconData icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final spacing = context.spacing;
    final accent = isDestructive ? colors.status.error : colors.brand.primary;

    return AppBottomSheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          SizedBox(height: spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textStyles.title.copyWith(fontSize: 20),
          ),
          SizedBox(height: spacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textStyles.body.copyWith(color: colors.text.secondary),
          ),
          SizedBox(height: spacing.lg),
          AppSheetButton(
            label: confirmLabel,
            filled: true,
            color: accent,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
          ),
          if (cancelLabel case final cancelLabel?) ...[
            SizedBox(height: spacing.sm),
            AppSheetButton(
              label: cancelLabel,
              filled: false,
              color: colors.text.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}
