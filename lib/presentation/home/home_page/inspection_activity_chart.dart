import 'package:beebase/domain/entity/day_count.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 30-day inspection activity trend — plain, no cubit/DI/API access. [data]
/// is expected exactly 30 entries, oldest to newest, zero-filled (as the
/// statistics API guarantees), plotted as-is.
final class InspectionActivityChart extends StatelessWidget {
  const InspectionActivityChart({required this.data, super.key});

  final List<DayCount> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final maxCount = data
        .map((day) => day.count)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxCount == 0 ? 1 : (maxCount + 1).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].count.toDouble()),
              ],
              isCurved: true,
              color: colors.brand.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.brand.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
