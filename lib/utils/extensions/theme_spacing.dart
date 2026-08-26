import 'package:beebase/utils/themes/spacing.dart';
import 'package:flutter/material.dart';

extension ThemeSpacingX on BuildContext {
  Spacing get spacing =>
      Theme.of(this).extension<Spacing>() ?? const Spacing.standard();
}
