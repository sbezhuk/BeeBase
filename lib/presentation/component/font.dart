import 'package:beebase/presentation/component/color.dart';
import 'package:flutter/material.dart';

abstract final class AppFont {
  static const bold = 'AvertaStd-Bold';
  static const semibold = 'AvertaStd-Semibold';
  static const regular = 'AvertaStd-Regular';
}

abstract final class AppTextStyles {
  static const title = TextStyle(fontFamily: AppFont.bold, fontSize: 24, color: AppColor.textPrimary);
  static const body = TextStyle(fontFamily: AppFont.regular, fontSize: 16, color: AppColor.textPrimary);
  static const label = TextStyle(fontFamily: AppFont.semibold, fontSize: 14, color: AppColor.textSecondary);
  static const button = TextStyle(fontFamily: AppFont.semibold, fontSize: 16, color: AppColor.background);
  static const error = TextStyle(fontFamily: AppFont.regular, fontSize: 13, color: AppColor.error);

  // Beekeeping auth theme (login/register screens)
  static const authTitle = TextStyle(
    fontFamily: AppFont.bold,
    fontSize: 23,
    fontWeight: FontWeight.w800,
    color: AppColor.hiveBrown,
    letterSpacing: -0.2,
  );
  static const authSubtitle = TextStyle(fontFamily: AppFont.regular, fontSize: 13.5, color: AppColor.honeyMuted, height: 1.5);
  static const authFieldLabel = TextStyle(fontFamily: AppFont.semibold, fontSize: 13, color: AppColor.hiveBrown);
  static const authMuted = TextStyle(fontFamily: AppFont.regular, fontSize: 13.5, color: AppColor.honeyMuted);
  static const authLink = TextStyle(fontFamily: AppFont.semibold, fontSize: 13.5, color: AppColor.primaryDark);
}
