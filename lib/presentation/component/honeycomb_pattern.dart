import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/component/honeycomb_painter.dart';
import 'package:flutter/material.dart';

/// Decorative honeycomb hexagon scatter, used as a subtle background flourish
/// on the beekeeping-themed auth screens.
final class HoneycombPattern extends StatelessWidget {
  const HoneycombPattern({this.color = AppColor.hiveBrown, this.opacity = 0.08, super.key});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: HoneycombPainter(color: color.withValues(alpha: opacity)),
      ),
    );
  }
}
