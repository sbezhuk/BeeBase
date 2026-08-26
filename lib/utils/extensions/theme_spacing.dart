import 'package:beebase/utils/extensions/theme_extension_x.dart';
import 'package:beebase/utils/themes/spacing.dart';
import 'package:flutter/material.dart';

extension ThemeSpacingX on BuildContext {
  Spacing get spacing => themeExtension(const Spacing.standard());
}
