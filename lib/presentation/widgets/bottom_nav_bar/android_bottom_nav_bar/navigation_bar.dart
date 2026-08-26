part of '../android_bottom_nav_bar.dart';

/// Compact-width presentation: a stock Material 3 [NavigationBar]. Deliberately
/// left un-themed beyond `ThemeData.colorScheme` — Flutter's M3 `NavigationBar`
/// already ships the current pill indicator, tonal elevation, and motion, so
/// hand-rolling any of that here would just fight the current Material spec.
final class _AndroidNavigationBar extends StatelessWidget {
  const _AndroidNavigationBar({required this.destinations, required this.selectedIndex, required this.onDestinationSelected});

  final List<BottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: _DestinationIcon(destination: destination, selected: false),
            selectedIcon: _DestinationIcon(destination: destination, selected: true),
            label: destination.label,
            tooltip: destination.accessibilityLabel,
            enabled: destination.enabled,
          ),
      ],
    );
  }
}
