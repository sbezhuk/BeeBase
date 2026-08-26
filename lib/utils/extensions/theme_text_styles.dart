import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_extension_x.dart';
import 'package:flutter/material.dart';

extension ThemeTextStylesX on BuildContext {
  AppTextStyles get textStyles => themeExtension(AppTextStyles.fromColors(colors));
}
