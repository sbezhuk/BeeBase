import 'package:beebase/presentation/apiary/widget/apiary_hexagon_badge.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Stands in wherever [ApiaryMapPhoto] has no coordinates to render — the
/// module's own honeycomb identity ([ApiaryHexagonBadge] over
/// [HoneycombPattern]) shown full-bleed at the height of the photo it
/// replaces. Shared by the details and form pages so every apiary hero
/// photo slot degrades the same way.
final class ApiaryPhotoPlaceholder extends StatelessWidget {
  const ApiaryPhotoPlaceholder({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      height: height,
      color: colors.honeyCreamLight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: HoneycombPattern(opacity: 0.16)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ApiaryHexagonBadge(size: 64),
              SizedBox(height: context.spacing.sm),
              Text('apiary.photoPlaceholder'.tr(), style: context.textStyles.label.copyWith(color: colors.honeyMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
