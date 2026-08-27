import 'package:flutter/widgets.dart';

/// An optional trailing action rendered in [ApiaryScaffold]'s nav bar — e.g.
/// "edit" on the details screen. Mirrors [BottomNavPrimaryAction]'s shape:
/// platform presentation differs (a floating Liquid Glass icon button on
/// iOS, a Material icon button on Android), so this only carries the
/// platform-agnostic content; each platform scaffold decides how to render it.
@immutable
final class ApiaryScaffoldAction {
  const ApiaryScaffoldAction({
    required this.label,
    required this.materialIcon,
    required this.cupertinoIcon,
    required this.onPressed,
  });

  /// Accessibility label / tooltip.
  final String label;

  /// Material Symbol used on Android.
  final IconData materialIcon;

  /// SF-Symbols-style Cupertino icon used on iOS.
  final IconData cupertinoIcon;

  final VoidCallback onPressed;
}
