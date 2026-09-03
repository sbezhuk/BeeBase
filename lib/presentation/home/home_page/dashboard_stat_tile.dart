import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

/// A single "label: value" stat shown inside a [DashboardSectionCard].
final class DashboardStatTile extends StatelessWidget {
  const DashboardStatTile({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: context.textStyles.body.copyWith(
              color: colors.text.secondary,
            ),
          ),
        ),
        Text(
          value,
          style: context.textStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
