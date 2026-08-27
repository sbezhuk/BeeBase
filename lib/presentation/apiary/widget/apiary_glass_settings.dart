import 'package:beebase/presentation/component/color.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shared Liquid Glass tuning for every iOS Apiary surface (nav buttons,
/// section cards, list tiles).
///
/// [LiquidGlassSettings]'s own default `glassColor` is fully transparent
/// (alpha 0) — clear glass, refraction/blur only, no tint — which reads as
/// a bare outline rather than a surface once it sits over a dark page. A
/// warm honey tint at real alpha is what gives these surfaces the "glass
/// with body" look instead.
LiquidGlassSettings apiaryGlassSettings(AppColor colors) {
  return LiquidGlassSettings(glassColor: colors.primary.withValues(alpha: 0.18), thickness: 24, blur: 6);
}
