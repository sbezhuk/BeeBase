import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints a scatter of hexagon outlines, positioned and scaled against a
/// [_referenceWidth]-wide reference frame then stretched to the canvas width.
final class HoneycombPainter extends CustomPainter {
  HoneycombPainter({required this.color});

  final Color color;

  static const _referenceWidth = 362.0;
  static const _baseRadius = 14.0;
  static const _hexagons = [
    (dx: 48.0, dy: 54.0, scale: 1.6),
    (dx: 320.0, dy: 40.0, scale: 1.1),
    (dx: 300.0, dy: 150.0, scale: 1.8),
    (dx: 30.0, dy: 180.0, scale: 1.2),
    (dx: 340.0, dy: 260.0, scale: 1.3),
    (dx: 90.0, dy: 130.0, scale: 0.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final scale = size.width / _referenceWidth;
    for (final hex in _hexagons) {
      final center = Offset(hex.dx * scale, hex.dy * scale);
      canvas.drawPath(_hexagonPath(center, _baseRadius * hex.scale * scale), paint);
    }
  }

  Path _hexagonPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (-90 + 60 * i) * math.pi / 180;
      final point = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter oldDelegate) => oldDelegate.color != color;
}
