import 'package:beebase/domain/entity/apiary_hive_count.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Bar chart of hives per apiary — plain, no cubit/DI/API access, so it's
/// independently testable/reusable. [data] is expected pre-sorted by the
/// statistics API (descending hive count).
final class HiveDistributionChart extends StatelessWidget {
  const HiveDistributionChart({required this.data, this.onBarTap, super.key});

  final List<ApiaryHiveCount> data;
  final void Function(ApiaryHiveCount apiary)? onBarTap;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final maxCount = data
        .map((item) => item.hiveCount)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxCount + 1).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              final index = response?.spot?.touchedBarGroupIndex;
              if (event is FlTapUpEvent &&
                  index != null &&
                  index >= 0 &&
                  index < data.length) {
                onBarTap?.call(data[index]);
              }
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: context.spacing.xs),
                    child: Text(
                      data[index].name,
                      style: context.textStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].hiveCount.toDouble(),
                    color: colors.brand.primary,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
