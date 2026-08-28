import 'package:flutter/material.dart';

/// Brand palette, exposed as a [ThemeExtension] so screens can switch between
/// [AppColor.light] and [AppColor.dark] via [ThemeData.extensions] and read
/// the active palette off the [BuildContext] (see `context.colors`).
@immutable
final class AppColor extends ThemeExtension<AppColor> {
  const AppColor({
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
    required this.border,
    required this.hiveBrown,
    required this.honeyMuted,
    required this.honeyPlaceholder,
    required this.honeyBorder,
    required this.honeyCream,
    required this.honeyCreamLight,
    required this.photoPlaceholder,
  });

  const AppColor.light()
    : this(
        primary: const Color(0xFFF7A21E),
        primaryDark: const Color(0xFFC97A0F),
        background: const Color(0xFFFFFFFF),
        surface: const Color(0xFFF5F5F5),
        textPrimary: const Color(0xFF1A1A1A),
        textSecondary: const Color(0xFF6B6B6B),
        error: const Color(0xFFD32F2F),
        border: const Color(0xFFDDDDDD),
        hiveBrown: const Color(0xFF3A2415),
        honeyMuted: const Color(0xFF8A7256),
        honeyPlaceholder: const Color(0xFFB7A88C),
        honeyBorder: const Color(0xFFEBDCC0),
        honeyCream: const Color(0xFFFDECC7),
        honeyCreamLight: const Color(0xFFFFF7E4),
        photoPlaceholder: const Color(0xFF2196F3),
      );

  // Same beekeeping/hive-and-honey palette as [AppColor.light], inverted for
  // a dark hive at night: near-black brown surfaces with the honey gold accent
  // kept bright, and the cream/brown roles that carried "ink on parchment"
  // contrast in light mode swapped for "honey on hive" contrast here.
  const AppColor.dark()
    : this(
        primary: const Color(0xFFFFB74D),
        primaryDark: const Color(0xFFC97A0F),
        background: const Color(0xFF1C130A),
        surface: const Color(0xFF2A1D10),
        textPrimary: const Color(0xFFFDECC7),
        textSecondary: const Color(0xFFC7B299),
        error: const Color(0xFFFF6B6B),
        border: const Color(0xFF4A3826),
        hiveBrown: const Color(0xFFF5E6C8),
        honeyMuted: const Color(0xFFB89B72),
        honeyPlaceholder: const Color(0xFF6B5A42),
        honeyBorder: const Color(0xFF4A3826),
        honeyCream: const Color(0xFF2A1D10),
        honeyCreamLight: const Color(0xFF1C130A),
        photoPlaceholder: const Color(0xFF2196F3),
      );

  final Color primary;
  final Color primaryDark;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color error;
  final Color border;

  // Beekeeping auth theme (login/register screens)
  final Color hiveBrown;
  final Color honeyMuted;
  final Color honeyPlaceholder;
  final Color honeyBorder;
  final Color honeyCream;
  final Color honeyCreamLight;

  // Stands in for real photo/map imagery that doesn't exist yet (e.g. the
  // apiary list tile) — fixed regardless of light/dark theme since it's a
  // placeholder block, not themed app chrome.
  final Color photoPlaceholder;

  @override
  AppColor copyWith({
    Color? primary,
    Color? primaryDark,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? error,
    Color? border,
    Color? hiveBrown,
    Color? honeyMuted,
    Color? honeyPlaceholder,
    Color? honeyBorder,
    Color? honeyCream,
    Color? honeyCreamLight,
    Color? photoPlaceholder,
  }) {
    return AppColor(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      error: error ?? this.error,
      border: border ?? this.border,
      hiveBrown: hiveBrown ?? this.hiveBrown,
      honeyMuted: honeyMuted ?? this.honeyMuted,
      honeyPlaceholder: honeyPlaceholder ?? this.honeyPlaceholder,
      honeyBorder: honeyBorder ?? this.honeyBorder,
      honeyCream: honeyCream ?? this.honeyCream,
      honeyCreamLight: honeyCreamLight ?? this.honeyCreamLight,
      photoPlaceholder: photoPlaceholder ?? this.photoPlaceholder,
    );
  }

  @override
  AppColor lerp(ThemeExtension<AppColor>? other, double t) {
    if (other is! AppColor) return this;
    return AppColor(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      error: Color.lerp(error, other.error, t)!,
      border: Color.lerp(border, other.border, t)!,
      hiveBrown: Color.lerp(hiveBrown, other.hiveBrown, t)!,
      honeyMuted: Color.lerp(honeyMuted, other.honeyMuted, t)!,
      honeyPlaceholder: Color.lerp(honeyPlaceholder, other.honeyPlaceholder, t)!,
      honeyBorder: Color.lerp(honeyBorder, other.honeyBorder, t)!,
      honeyCream: Color.lerp(honeyCream, other.honeyCream, t)!,
      honeyCreamLight: Color.lerp(honeyCreamLight, other.honeyCreamLight, t)!,
      photoPlaceholder: Color.lerp(photoPlaceholder, other.photoPlaceholder, t)!,
    );
  }
}
