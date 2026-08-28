import 'package:flutter/material.dart';

/// Body text ink — headings/labels vs. muted secondary copy.
@immutable
final class AppTextColors {
  const AppTextColors({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  AppTextColors copyWith({Color? primary, Color? secondary}) {
    return AppTextColors(primary: primary ?? this.primary, secondary: secondary ?? this.secondary);
  }

  AppTextColors lerp(AppTextColors other, double t) {
    return AppTextColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
    );
  }
}
