import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// iOS 26 / Liquid Glass floating tab bar.
///
/// Built on the vendored `liquid_glass_widgets` package (`plugins/liquid_glass_widgets`)
/// rather than a hand-rolled `BackdropFilter` approximation — it's a real
/// fragment-shader implementation (genuine backdrop refraction, specular
/// highlights, jelly-physics selection), which is the only way to get an
/// authentic Liquid Glass surface out of Flutter today. [GlassScaffold] +
/// [GlassTabBar.bottom] handle safe-area clearance, bar/body z-ordering, and
/// scroll edge fading internally, so this widget only maps our platform-agnostic
/// [BottomNavDestination] model onto the package's [GlassTab] type.
final class IosBottomNavigationBar extends StatelessWidget {
  const IosBottomNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
  });

  final List<BottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: body,
      // GlassTabBar's label/badge text renders outside any ancestor
      // DefaultTextStyle that resolves to a real style — without this it
      // falls back to a bare TextStyle() and paints with a debug-yellow
      // double underline. `Material` fixes that (it unconditionally wraps
      // its child in a fresh AnimatedDefaultTextStyle sourced from
      // Theme.textTheme.bodyMedium), but MaterialType.canvas also paints an
      // opaque surface that blocks the glass shader's backdrop sampling.
      // `MaterialType.transparency` gets the same DefaultTextStyle fix while
      // painting nothing, so the blur/refraction underneath is untouched.
      bottomBar: Material(
        type: MaterialType.transparency,
        child: GlassTabBar.bottom(
          tabs: [
            for (final destination in destinations) _toGlassTab(destination),
          ],
          selectedIndex: selectedIndex,
          onTabSelected: onDestinationSelected,
        ),
      ),
    );
  }
}

GlassTab _toGlassTab(BottomNavDestination destination) {
  Widget buildIcon(IconData data) {
    final glyph = Icon(data);
    // GlassTab has no first-class disabled state; dim manually. Taps are
    // already swallowed upstream in PlatformBottomNavigationBar before
    // onTabSelected is invoked, so this is presentation-only.
    final styled = destination.enabled
        ? glyph
        : Opacity(opacity: 0.4, child: glyph);
    final badgeCount = destination.badgeCount;
    return badgeCount == null
        ? styled
        : GlassBadge(count: badgeCount, child: styled);
  }

  // GlassTabBar's internal layout wraps the whole icon+label subtree
  // (including any GlassBadge inside it) in ExcludeSemantics, and speaks
  // GlassTab.semanticLabel as the tab's one accessibility node — so the
  // badge count has to be folded in here rather than left to GlassBadge's
  // own (otherwise-excluded) semantics.
  final badgeCount = destination.badgeCount;
  final semanticLabel = badgeCount == null
      ? destination.accessibilityLabel
      : '${destination.accessibilityLabel}, $badgeCount new';

  return GlassTab(
    icon: buildIcon(destination.cupertinoIcon),
    activeIcon: buildIcon(destination.cupertinoIconSelected),
    label: destination.label,
    semanticLabel: semanticLabel,
  );
}
