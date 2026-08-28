import 'package:flutter/material.dart';

/// Beekeeping auth theme — the honey-on-hive palette behind the
/// login/register screens and the honeycomb motifs elsewhere.
@immutable
final class AppHoneyColors {
  const AppHoneyColors({
    required this.brown,
    required this.muted,
    required this.placeholder,
    required this.border,
    required this.cream,
    required this.creamLight,
  });

  final Color brown;
  final Color muted;
  final Color placeholder;
  final Color border;
  final Color cream;
  final Color creamLight;

  AppHoneyColors copyWith({
    Color? brown,
    Color? muted,
    Color? placeholder,
    Color? border,
    Color? cream,
    Color? creamLight,
  }) {
    return AppHoneyColors(
      brown: brown ?? this.brown,
      muted: muted ?? this.muted,
      placeholder: placeholder ?? this.placeholder,
      border: border ?? this.border,
      cream: cream ?? this.cream,
      creamLight: creamLight ?? this.creamLight,
    );
  }

  AppHoneyColors lerp(AppHoneyColors other, double t) {
    return AppHoneyColors(
      brown: Color.lerp(brown, other.brown, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      border: Color.lerp(border, other.border, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      creamLight: Color.lerp(creamLight, other.creamLight, t)!,
    );
  }
}
