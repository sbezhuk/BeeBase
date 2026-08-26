import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/utils/extensions/theme_extension_x.dart';
import 'package:flutter/material.dart';

extension ThemeColorX on BuildContext {
  AppColor get colors => themeExtension(const AppColor.light());
}
