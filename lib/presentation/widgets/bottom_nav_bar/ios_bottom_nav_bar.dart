import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_primary_action.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// iOS 26 / Liquid Glass floating tab bar.
///
/// Built on the vendored `liquid_glass_widgets` package (`plugins/liquid_glass_widgets`)
/// rather than a hand-rolled `BackdropFilter` approximation — it's a real
/// fragment-shader implementation (genuine backdrop refraction, specular
/// highlights, jelly-physics selection), which is the only way to get an
/// authentic Liquid Glass surface out of Flutter today. [GlassScaffold] +
/// [GlassTabBar.minimizable] handle safe-area clearance, bar/body z-ordering,
/// and scroll edge fading internally, so this widget only maps our
/// platform-agnostic [BottomNavDestination] model onto the package's
/// [GlassTab] type. `.minimizable` (rather than `.bottom`) is used solely
/// for its spring-animated [GlassTabBarTrailingButton] slot — see the note
/// on [primaryAction] below.
final class IosBottomNavigationBar extends StatelessWidget {
  const IosBottomNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.primaryAction,
    super.key,
  });

  final List<BottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final BottomNavPrimaryAction? primaryAction;

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
        // GlassTabBar.bottom's `extraButton` has no transition of its own:
        // toggling it resizes the tab pill on the very next frame, which
        // read as an abrupt "twitch" whenever primaryAction changed (i.e.
        // switching to/from the Apiaries tab). `.minimizable`'s
        // `trailingButton` renders in the same slot but — per its own
        // docs — "shares the bar's glass blend layer, morphs with the same
        // springs" as the tab pill: it's driven by the bar's own
        // AnimationControllers rather than a widget swap, which is what
        // gives it a native, physical feel instead of a cross-fade. We
        // never minimize (no scroll-driven collapse here), so this is
        // just a plain always-expanded tab bar with a spring-animated
        // trailing action.
        child: GlassTabBar.minimizable(
          tabs: [for (final destination in destinations) _toGlassTab(destination)],
          selectedIndex: selectedIndex,
          onTabSelected: onDestinationSelected,
          trailingButton: _toTrailingButton(primaryAction),
        ),
      ),
    );
  }
}

GlassTabBarTrailingButton? _toTrailingButton(BottomNavPrimaryAction? action) {
  if (action == null) return null;
  return GlassTabBarTrailingButton(
    // GlassTabBarTrailingButton has no accessibility-label field of its
    // own (unlike GlassTabBarExtraButton) — wrap the glyph so screen
    // readers still get a real label instead of a bare icon.
    icon: Semantics(button: true, label: action.accessibilityLabel, child: Icon(action.cupertinoIcon)),
    onTap: action.onPressed,
  );
}

GlassTab _toGlassTab(BottomNavDestination destination) {
  Widget buildIcon(IconData data) {
    final glyph = Icon(data);
    // GlassTab has no first-class disabled state; dim manually. Taps are
    // already swallowed upstream in PlatformBottomNavigationBar before
    // onTabSelected is invoked, so this is presentation-only.
    final styled = destination.enabled ? glyph : Opacity(opacity: 0.4, child: glyph);
    final badgeCount = destination.badgeCount;
    return badgeCount == null ? styled : GlassBadge(count: badgeCount, child: styled);
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
