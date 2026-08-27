import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints a single filled hexagon — [ApiaryHexagonBadge]'s backdrop. Shares
/// the hexagon-path math used by [HoneycombPainter] for the honeycomb motif,
/// but fills a single cell instead of stroking a scatter of them.
final class ApiaryHexagonPainter extends CustomPainter {
  ApiaryHexagonPainter({required this.color, this.borderColor});

  final Color color;
  final Color? borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final path = _hexagonPath(center, radius);
    canvas.drawPath(path, Paint()..color = color);
    final border = borderColor;
    if (border != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
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
  bool shouldRepaint(covariant ApiaryHexagonPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
