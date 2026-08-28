import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

part 'confirmation_sheet_button.dart';

/// Shows a [ConfirmationSheet] as a modal bottom sheet, matching the app's
/// honey/hive palette. Used for a "are you sure?" step before a
/// consequential action — e.g. deleting an apiary.
Future<void> showConfirmationSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  required VoidCallback onConfirm,
  IconData icon = Icons.warning_amber_rounded,
  bool isDestructive = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
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

/// Content of a themed confirmation bottom sheet: an icon, a title and
/// message, then a full-width confirm/cancel button pair.
final class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    this.icon = Icons.warning_amber_rounded,
    this.isDestructive = true,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final IconData icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final spacing = context.spacing;
    final accent = isDestructive ? colors.status.error : colors.brand.primary;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(spacing.sm),
        padding: EdgeInsets.fromLTRB(spacing.lg, spacing.sm, spacing.lg, spacing.lg),
        decoration: BoxDecoration(
          color: colors.surface.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.honey.border),
          boxShadow: [
            BoxShadow(color: colors.honey.brown.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: EdgeInsets.only(bottom: spacing.md),
              decoration: BoxDecoration(color: colors.honey.border, borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 26),
            ),
            SizedBox(height: spacing.md),
            Text(title, textAlign: TextAlign.center, style: textStyles.title.copyWith(fontSize: 20)),
            SizedBox(height: spacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textStyles.body.copyWith(color: colors.text.secondary),
            ),
            SizedBox(height: spacing.lg),
            _ConfirmationSheetButton(
              label: confirmLabel,
              filled: true,
              color: accent,
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
            SizedBox(height: spacing.sm),
            _ConfirmationSheetButton(
              label: cancelLabel,
              filled: false,
              color: colors.text.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
