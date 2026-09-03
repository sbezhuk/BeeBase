import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

/// A labeled content surface for one Dashboard section — mirrors
/// `ApiarySectionCard`'s shape, kept local to this feature rather than
/// imported cross-feature.
final class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: colors.surface.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.title),
          SizedBox(height: context.spacing.md),
          child,
        ],
      ),
    );
  }
}
