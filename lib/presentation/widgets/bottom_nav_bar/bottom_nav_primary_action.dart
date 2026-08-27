import 'package:flutter/widgets.dart';

/// An optional primary action rendered alongside [PlatformBottomNavigationBar]
/// — e.g. "create" on a list screen's tab. Platform presentation differs
/// (a Liquid Glass capsule beside the tab bar on iOS, a floating action
/// button above the bar on Android), so this only carries the
/// platform-agnostic content; each platform's bar decides how to render it.
@immutable
final class BottomNavPrimaryAction {
  const BottomNavPrimaryAction({
    required this.label,
    required this.materialIcon,
    required this.cupertinoIcon,
    required this.onPressed,
    this.semanticLabel,
  });

  /// Visible label (Android's extended FAB) / accessibility label fallback.
  final String label;

  /// Material Symbol used on Android.
  final IconData materialIcon;

  /// SF-Symbols-style Cupertino icon used on iOS.
  final IconData cupertinoIcon;

  final VoidCallback onPressed;

  /// Overrides [label] for screen readers.
  final String? semanticLabel;

  String get accessibilityLabel => semanticLabel ?? label;
}
