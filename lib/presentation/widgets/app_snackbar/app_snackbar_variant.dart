import 'package:beebase/presentation/component/color.dart';
import 'package:flutter/material.dart';

/// Semantic tone for [AppSnackBarCard]'s left accent bar — pick the variant
/// that matches what the message tells the user, not a specific color. Add a
/// new case here (and a branch in [AppSnackBarVariantX.accentColor]) to
/// introduce another tone.
enum AppSnackBarVariant { neutral, success, error }

extension AppSnackBarVariantX on AppSnackBarVariant {
  Color accentColor(AppColor colors) => switch (this) {
    AppSnackBarVariant.neutral => colors.honey.muted,
    AppSnackBarVariant.success => colors.brand.primary,
    AppSnackBarVariant.error => colors.status.error,
  };
}
