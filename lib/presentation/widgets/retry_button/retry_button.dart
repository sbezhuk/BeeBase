import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The single retry CTA for a failed network request — a plain text button
/// with a refresh icon, styled like the app's other inline text actions
/// (see `textStyles.action`). Centralizes what used to be a
/// `_RetryButton`/`_DashboardRetryButton`-style private class copy-pasted
/// per feature (apiary/hive/inspection lists, dashboard) so every retry
/// action looks and behaves the same.
final class RetryButton extends StatelessWidget {
  const RetryButton({required this.onPressed, this.label, super.key});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh),
      label: Text(label ?? 'core.common.retry'.tr()),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.brand.primaryDark,
        textStyle: context.textStyles.action,
      ),
    );
  }
}
