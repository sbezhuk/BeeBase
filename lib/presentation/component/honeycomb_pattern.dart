import 'package:beebase/presentation/component/honeycomb_painter.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Decorative honeycomb hexagon scatter, used as a subtle background flourish
/// on the beekeeping-themed auth screens.
final class HoneycombPattern extends StatelessWidget {
  const HoneycombPattern({this.color, this.opacity = 0.08, super.key});

  /// Defaults to `context.colors.hiveBrown` when unset, so the pattern tracks
  /// the active light/dark palette.
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: HoneycombPainter(color: (color ?? context.colors.hiveBrown).withValues(alpha: opacity)),
      ),
    );
  }
}
