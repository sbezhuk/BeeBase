import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

/// A labeled content surface shared by the Hive details and form pages —
/// mirrors [ApiarySectionCard]. Kept as a single reusable widget so neither
/// page hand-rolls its own card chrome.
final class HiveSectionCard extends StatelessWidget {
  const HiveSectionCard({required this.child, this.label, super.key});

  /// Small uppercase section header shown above [child]. Omit for a plain
  /// card with no header.
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = label == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label!.toUpperCase(),
                style: context.textStyles.label.copyWith(
                  color: colors.honey.muted,
                ),
              ),
              SizedBox(height: context.spacing.sm),
              child,
            ],
          );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: colors.surface.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
    );
  }
}
