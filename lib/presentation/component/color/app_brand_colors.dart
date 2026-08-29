import 'package:flutter/material.dart';

/// The brand accent — buttons, focus states, selected chrome.
@immutable
final class AppBrandColors {
  const AppBrandColors({required this.primary, required this.primaryDark, required this.onPrimary});

  final Color primary;
  final Color primaryDark;

  // Content (text/icons/spinners) drawn on top of the primary gradient —
  // a dark ink that contrasts with the gold accent itself, so it stays the
  // same regardless of overall theme brightness. Never reuse a surface
  // color for this: unlike surface tones, it must not flip with the theme.
  final Color onPrimary;

  AppBrandColors copyWith({Color? primary, Color? primaryDark, Color? onPrimary}) {
    return AppBrandColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      onPrimary: onPrimary ?? this.onPrimary,
    );
  }

  AppBrandColors lerp(AppBrandColors other, double t) {
    return AppBrandColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}
