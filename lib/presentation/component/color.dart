import 'package:beebase/presentation/component/color/app_brand_colors.dart';
import 'package:beebase/presentation/component/color/app_honey_colors.dart';
import 'package:beebase/presentation/component/color/app_status_colors.dart';
import 'package:beebase/presentation/component/color/app_surface_colors.dart';
import 'package:beebase/presentation/component/color/app_text_colors.dart';
import 'package:flutter/material.dart';

/// Brand palette, exposed as a [ThemeExtension] and registered on
/// [ThemeData.extensions] so screens can read the active (dark-only)
/// palette off the [BuildContext] (see `context.colors`).
///
/// Grouped into small themed value objects ([AppBrandColors],
/// [AppSurfaceColors], [AppTextColors], [AppStatusColors], [AppHoneyColors])
/// rather than one flat field list — adding a new token means adding a field
/// to the relevant group (and its `copyWith`/`lerp`), not touching this
/// class. Start a new group only once a color doesn't fit any existing one.
@immutable
final class AppColor extends ThemeExtension<AppColor> {
  const AppColor({
    required this.brand,
    required this.surface,
    required this.text,
    required this.status,
    required this.honey,
    required this.photoPlaceholder,
  });

  // Beekeeping/hive-and-honey palette for a dark hive at night: near-black
  // brown surfaces with the honey gold accent kept bright.
  const AppColor.dark()
    : this(
        brand: const AppBrandColors(primary: Color(0xFFE8AC3D), primaryDark: Color(0xFFC97A0F)),
        surface: const AppSurfaceColors(
          background: Color(0xFF1C130A),
          card: Color(0xFF332212),
          border: Color(0xFF4A3826),
        ),
        text: const AppTextColors(primary: Color(0xFFFDECC7), secondary: Color(0xFFC7B299)),
        status: const AppStatusColors(error: Color(0xFFFF6B6B)),
        honey: const AppHoneyColors(
          brown: Color(0xFFF5E6C8),
          muted: Color(0xFFB89B72),
          placeholder: Color(0xFF6B5A42),
          border: Color(0xFF4A3826),
          cream: Color(0xFF2A1D10),
          creamLight: Color(0xFF1C130A),
        ),
        photoPlaceholder: const Color(0xFF2196F3),
      );

  final AppBrandColors brand;
  final AppSurfaceColors surface;
  final AppTextColors text;
  final AppStatusColors status;
  final AppHoneyColors honey;

  // Stands in for real photo/map imagery that doesn't exist yet (e.g. the
  // apiary list tile) — fixed regardless of theme since it's a placeholder
  // block, not themed app chrome.
  final Color photoPlaceholder;

  @override
  AppColor copyWith({
    AppBrandColors? brand,
    AppSurfaceColors? surface,
    AppTextColors? text,
    AppStatusColors? status,
    AppHoneyColors? honey,
    Color? photoPlaceholder,
  }) {
    return AppColor(
      brand: brand ?? this.brand,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      status: status ?? this.status,
      honey: honey ?? this.honey,
      photoPlaceholder: photoPlaceholder ?? this.photoPlaceholder,
    );
  }

  @override
  AppColor lerp(ThemeExtension<AppColor>? other, double t) {
    if (other is! AppColor) return this;
    return AppColor(
      brand: brand.lerp(other.brand, t),
      surface: surface.lerp(other.surface, t),
      text: text.lerp(other.text, t),
      status: status.lerp(other.status, t),
      honey: honey.lerp(other.honey, t),
      photoPlaceholder: Color.lerp(photoPlaceholder, other.photoPlaceholder, t)!,
    );
  }
}
