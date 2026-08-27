import 'package:beebase/presentation/apiary/widget/apiary_hexagon_painter.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Honeycomb-cell icon badge — the apiary module's signature visual motif.
/// Used as the list tile leading glyph and the details page header icon so
/// every apiary touchpoint shares the same hive identity.
final class ApiaryHexagonBadge extends StatelessWidget {
  const ApiaryHexagonBadge({this.icon = Icons.hive, this.size = 44, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ApiaryHexagonPainter(color: colors.honeyCream, borderColor: colors.honeyBorder),
        child: Center(
          child: Icon(icon, color: colors.primaryDark, size: size * 0.5),
        ),
      ),
    );
  }
}
