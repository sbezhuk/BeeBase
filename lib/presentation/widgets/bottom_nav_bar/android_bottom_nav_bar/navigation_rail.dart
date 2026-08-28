part of '../android_bottom_nav_bar.dart';

/// Expanded-width presentation: a Material 3 [NavigationRail] docked to the
/// leading edge, per Material's guidance to move top-level destinations off
/// a bottom bar once there's enough width for a rail (tablets, foldables,
/// landscape).
final class _AndroidNavigationRail extends StatelessWidget {
  const _AndroidNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<BottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: _DestinationIcon(destination: destination, selected: false),
            selectedIcon: _DestinationIcon(destination: destination, selected: true),
            label: Semantics(
              label: destination.accessibilityLabel,
              child: ExcludeSemantics(child: Text(destination.label)),
            ),
            disabled: !destination.enabled,
          ),
      ],
    );
  }
}
