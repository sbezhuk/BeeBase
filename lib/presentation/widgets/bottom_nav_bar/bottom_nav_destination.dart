import 'package:flutter/widgets.dart';

/// A single top-level destination for [PlatformBottomNavigationBar].
///
/// Carries a separate icon per platform so iOS renders Cupertino/SF-Symbols-style
/// glyphs and Android renders Material Symbols — never the other platform's
/// icon family.
@immutable
final class BottomNavDestination {
  const BottomNavDestination({
    required this.label,
    required this.materialIcon,
    required this.materialIconSelected,
    required this.cupertinoIcon,
    IconData? cupertinoIconSelected,
    this.semanticLabel,
    this.badgeCount,
    this.enabled = true,
  }) : cupertinoIconSelected = cupertinoIconSelected ?? cupertinoIcon;

  /// Visible label shown under the icon.
  final String label;

  /// Overrides [label] for screen readers, e.g. to spell out an abbreviation.
  final String? semanticLabel;

  /// Material Symbol used on Android in the unselected/selected state.
  final IconData materialIcon;
  final IconData materialIconSelected;

  /// SF-Symbols-style Cupertino icon used on iOS in the unselected/selected
  /// state. Falls back to [cupertinoIcon] when no distinct selected glyph
  /// (e.g. a filled variant) is available.
  final IconData cupertinoIcon;
  final IconData cupertinoIconSelected;

  /// Count shown in a badge over the icon. `null` or non-positive hides it.
  final int? badgeCount;

  /// Whether this destination can be selected.
  final bool enabled;

  String get accessibilityLabel => semanticLabel ?? label;
}
