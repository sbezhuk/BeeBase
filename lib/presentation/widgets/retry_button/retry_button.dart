import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// The single retry CTA for a failed network request — a glass button on
/// iOS, a filled-tonal button elsewhere, matching the platform-adaptive
/// style already used throughout the app. Centralizes what used to be a
/// `_RetryButton`/`_DashboardRetryButton`-style private class copy-pasted
/// per feature (apiary/hive/inspection lists, dashboard) so every retry
/// action looks and behaves the same.
final class RetryButton extends StatelessWidget {
  const RetryButton({
    required this.onPressed,
    this.label,
    this.width = 140,
    this.height = 44,
    super.key,
  });

  final VoidCallback onPressed;
  final String? label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = label ?? 'core.common.retry'.tr();
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => GlassButton.custom(onTap: onPressed, width: width, height: height, child: Text(text)),
      _ => FilledButton.tonal(onPressed: onPressed, child: Text(text)),
    };
  }
}
