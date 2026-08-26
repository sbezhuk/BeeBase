import 'package:flutter/material.dart';

/// Generic accessor for a value registered on [ThemeData.extensions].
///
/// Every themed value in the app (colors, text styles, spacing, ...) is a
/// `final class` extending `ThemeExtension<T>`, registered once per
/// brightness in `application.dart`'s `_buildTheme`, and read through a
/// small `context.xxx` getter built on top of this helper — see
/// `theme_colors.dart`, `theme_text_styles.dart`, `theme_spacing.dart`.
///
/// To add a new themed value:
/// 1. Write it as a `final class` extending `ThemeExtension<T>`.
/// 2. Register a light/dark instance in `_buildTheme`.
/// 3. Add a one-line `BuildContext` extension: `context.themeExtension(T.light())`.
extension ThemeExtensionX on BuildContext {
  T themeExtension<T extends ThemeExtension<T>>(T fallback) => Theme.of(this).extension<T>() ?? fallback;
}
