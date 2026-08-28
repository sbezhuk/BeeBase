import 'package:flutter/material.dart';

/// The brand accent — buttons, focus states, selected chrome.
@immutable
final class AppBrandColors {
  const AppBrandColors({required this.primary, required this.primaryDark});

  final Color primary;
  final Color primaryDark;

  AppBrandColors copyWith({Color? primary, Color? primaryDark}) {
    return AppBrandColors(primary: primary ?? this.primary, primaryDark: primaryDark ?? this.primaryDark);
  }

  AppBrandColors lerp(AppBrandColors other, double t) {
    return AppBrandColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
    );
  }
}
