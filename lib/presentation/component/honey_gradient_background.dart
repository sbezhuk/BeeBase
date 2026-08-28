import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Full-bleed honey gradient backdrop shared by the beekeeping-themed
/// screens: top-to-bottom from [AppColor.honeyCream] through
/// [AppColor.honeyCreamLight] into [AppColor.background] — the same wash
/// used behind the login/register forms.
final class HoneyGradientBackground extends StatelessWidget {
  const HoneyGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.honey.cream, colors.honey.creamLight, colors.surface.background],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}
