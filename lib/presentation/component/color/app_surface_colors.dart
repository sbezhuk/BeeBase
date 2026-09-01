import 'package:flutter/material.dart';

/// Structural chrome shared by every screen: the page backdrop, card/input
/// fills, dividing borders, and the dimming layer behind a loading overlay.
@immutable
final class AppSurfaceColors {
  const AppSurfaceColors({required this.background, required this.card, required this.border, required this.scrim});

  final Color background;
  final Color card;
  final Color border;

  /// Backdrop painted behind a centered spinner (see `LoadingOverlay`) while
  /// a list is loading — black-based in both themes, since a dimming scrim
  /// isn't a brand surface and needs to read as "dimmed" against either
  /// palette rather than tracking hue.
  final Color scrim;

  AppSurfaceColors copyWith({Color? background, Color? card, Color? border, Color? scrim}) {
    return AppSurfaceColors(
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
      scrim: scrim ?? this.scrim,
    );
  }

  AppSurfaceColors lerp(AppSurfaceColors other, double t) {
    return AppSurfaceColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
