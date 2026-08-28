import 'package:flutter/material.dart';

@immutable
final class Spacing extends ThemeExtension<Spacing> {
  const Spacing({required this.xs, required this.sm, required this.md, required this.lg, required this.xl});

  const Spacing.standard() : this(xs: 4, sm: 8, md: 16, lg: 24, xl: 32);

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  @override
  Spacing copyWith({double? xs, double? sm, double? md, double? lg, double? xl}) {
    return Spacing(xs: xs ?? this.xs, sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg, xl: xl ?? this.xl);
  }

  @override
  Spacing lerp(ThemeExtension<Spacing>? other, double t) {
    if (other is! Spacing) return this;
    return Spacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
