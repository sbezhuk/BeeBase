import 'package:flutter/material.dart';

/// Structural chrome shared by every screen: the page backdrop, card/input
/// fills, and dividing borders.
@immutable
final class AppSurfaceColors {
  const AppSurfaceColors({required this.background, required this.card, required this.border});

  final Color background;
  final Color card;
  final Color border;

  AppSurfaceColors copyWith({Color? background, Color? card, Color? border}) {
    return AppSurfaceColors(
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
    );
  }

  AppSurfaceColors lerp(AppSurfaceColors other, double t) {
    return AppSurfaceColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
