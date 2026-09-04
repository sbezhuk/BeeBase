import 'package:beebase/presentation/apiary/widget/apiary_hexagon_badge.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Stands in for an apiary's hero photo — the module's own honeycomb
/// identity ([ApiaryHexagonBadge] over [HoneycombPattern]) shown full-bleed
/// at the height of the photo slot it fills. Shared by the list, details,
/// and form pages so every apiary hero photo slot degrades the same way.
/// [titleKey]/[subtitleKey] let a caller swap the copy while keeping the
/// same visual identity — never introduce a second placeholder widget for
/// a different message.
final class ApiaryPhotoPlaceholder extends StatelessWidget {
  const ApiaryPhotoPlaceholder({required this.height, this.titleKey = 'apiary.photo_placeholder', this.subtitleKey, super.key});

  final double height;
  final String titleKey;
  final String? subtitleKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      height: height,
      color: colors.honey.creamLight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: HoneycombPattern(opacity: 0.16)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ApiaryHexagonBadge(size: 64),
                SizedBox(height: context.spacing.sm),
                Text(
                  titleKey.tr(),
                  textAlign: TextAlign.center,
                  style: context.textStyles.label.copyWith(color: colors.honey.muted),
                ),
                if (subtitleKey != null) ...[
                  SizedBox(height: context.spacing.xs),
                  Text(
                    subtitleKey!.tr(),
                    textAlign: TextAlign.center,
                    style: context.textStyles.label.copyWith(color: colors.honey.muted.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
