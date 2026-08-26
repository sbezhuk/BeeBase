import 'package:beebase/presentation/component/color.dart';
import 'package:flutter/material.dart';

abstract final class AppFont {
  static const bold = 'AvertaStd-Bold';
  static const semibold = 'AvertaStd-Semibold';
  static const regular = 'AvertaStd-Regular';
}

abstract final class AppTextStyles {
  static const title = TextStyle(
    fontFamily: AppFont.bold,
    fontSize: 24,
    color: AppColor.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: AppFont.regular,
    fontSize: 16,
    color: AppColor.textPrimary,
  );
  static const label = TextStyle(
    fontFamily: AppFont.semibold,
    fontSize: 14,
    color: AppColor.textSecondary,
  );
  static const button = TextStyle(
    fontFamily: AppFont.semibold,
    fontSize: 16,
    color: AppColor.background,
  );
  static const error = TextStyle(
    fontFamily: AppFont.regular,
    fontSize: 13,
    color: AppColor.error,
  );
}
