import 'package:beebase/presentation/component/color.dart';
import 'package:flutter/material.dart';

abstract final class AppFont {
  // Titles — RobotoSlab, a serif slab reserved for display-scale headlines.
  static const titleBold = 'RobotoSlab-Bold';
  static const titleRegular = 'RobotoSlab-Regular';

  // Everything else — IBM Plex Sans.
  static const bold = 'IBMPlexSans-Bold';
  static const regular = 'IBMPlexSans-Regular';
}

/// Text style presets, exposed as a [ThemeExtension] because their colors
/// are drawn from [AppColor] and must switch with it — build one per palette
/// via [AppTextStyles.fromColors] and read the active set via
/// `context.textStyles`.
@immutable
final class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.title,
    required this.body,
    required this.label,
    required this.button,
    required this.error,
    required this.action,
    required this.authTitle,
    required this.authSubtitle,
    required this.authFieldLabel,
    required this.authMuted,
    required this.authLink,
  });

  factory AppTextStyles.fromColors(AppColor colors) {
    return AppTextStyles(
      title: TextStyle(
        fontFamily: AppFont.titleBold,
        fontSize: 26,
        height: 1.15,
        letterSpacing: -0.4,
        color: colors.text.primary,
      ),
      body: TextStyle(fontFamily: AppFont.regular, fontSize: 16, height: 1.5, color: colors.text.primary),
      label: TextStyle(fontFamily: AppFont.bold, fontSize: 12, letterSpacing: 0.8, color: colors.text.secondary),
      button: TextStyle(fontFamily: AppFont.bold, fontSize: 16, letterSpacing: 0.4, color: colors.surface.background),
      error: TextStyle(fontFamily: AppFont.regular, fontSize: 13, color: colors.status.error),
      action: TextStyle(fontFamily: AppFont.bold, fontSize: 14, letterSpacing: 0.2, color: colors.brand.primaryDark),
      authTitle: TextStyle(
        fontFamily: AppFont.titleBold,
        fontSize: 30,
        height: 1.1,
        letterSpacing: -0.6,
        color: colors.honey.brown,
      ),
      authSubtitle: TextStyle(
        fontFamily: AppFont.titleRegular,
        fontSize: 14,
        height: 1.5,
        letterSpacing: 0.1,
        color: colors.honey.muted,
      ),
      authFieldLabel: TextStyle(
        fontFamily: AppFont.bold,
        fontSize: 11.5,
        letterSpacing: 0.8,
        color: colors.honey.brown,
      ),
      authMuted: TextStyle(fontFamily: AppFont.regular, fontSize: 13.5, height: 1.4, color: colors.honey.muted),
      authLink: TextStyle(
        fontFamily: AppFont.bold,
        fontSize: 13.5,
        letterSpacing: 0.1,
        color: colors.brand.primaryDark,
      ),
    );
  }

  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle button;
  final TextStyle error;
  final TextStyle action;

  // Beekeeping auth theme (login/register screens)
  final TextStyle authTitle;
  final TextStyle authSubtitle;
  final TextStyle authFieldLabel;
  final TextStyle authMuted;
  final TextStyle authLink;

  @override
  AppTextStyles copyWith({
    TextStyle? title,
    TextStyle? body,
    TextStyle? label,
    TextStyle? button,
    TextStyle? error,
    TextStyle? action,
    TextStyle? authTitle,
    TextStyle? authSubtitle,
    TextStyle? authFieldLabel,
    TextStyle? authMuted,
    TextStyle? authLink,
  }) {
    return AppTextStyles(
      title: title ?? this.title,
      body: body ?? this.body,
      label: label ?? this.label,
      button: button ?? this.button,
      error: error ?? this.error,
      action: action ?? this.action,
      authTitle: authTitle ?? this.authTitle,
      authSubtitle: authSubtitle ?? this.authSubtitle,
      authFieldLabel: authFieldLabel ?? this.authFieldLabel,
      authMuted: authMuted ?? this.authMuted,
      authLink: authLink ?? this.authLink,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) return this;
    return AppTextStyles(
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      error: TextStyle.lerp(error, other.error, t)!,
      action: TextStyle.lerp(action, other.action, t)!,
      authTitle: TextStyle.lerp(authTitle, other.authTitle, t)!,
      authSubtitle: TextStyle.lerp(authSubtitle, other.authSubtitle, t)!,
      authFieldLabel: TextStyle.lerp(authFieldLabel, other.authFieldLabel, t)!,
      authMuted: TextStyle.lerp(authMuted, other.authMuted, t)!,
      authLink: TextStyle.lerp(authLink, other.authLink, t)!,
    );
  }
}
