import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_primary_action.dart';
import 'package:flutter/material.dart';

part 'android_bottom_nav_bar/destination_icon.dart';
part 'android_bottom_nav_bar/navigation_bar.dart';
part 'android_bottom_nav_bar/navigation_rail.dart';

// Material's large-screen breakpoint: below it a phone-style compact layout
// applies, at or above it there's enough width for a persistent side rail.
const _expandedLayoutBreakpoint = 600.0;

/// Adaptive Material 3 (Expressive) navigation.
///
/// Renders a bottom [NavigationBar] on compact widths and a side
/// [NavigationRail] once the window is wide enough to be a tablet/foldable,
/// so a single call site works across phones and larger screens without the
/// app choosing between the two itself. Both delegate their visuals entirely
/// to `ThemeData.colorScheme` (see `application.dart`), so they automatically
/// track the app's Material 3 palette, dynamic color, and light/dark mode.
final class AndroidBottomNavigationBar extends StatelessWidget {
  const AndroidBottomNavigationBar({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Set on the *outer* Scaffold (the one that also owns the bottom
        // bar/rail) rather than a per-page Scaffold, so Flutter's own FAB
        // layout floats it above the bar with the standard Material margin,
        // instead of a per-page FAB competing with the bar for the same
        // corner.
        final floatingActionButton = _toFab(primaryAction);

        if (constraints.maxWidth >= _expandedLayoutBreakpoint) {
          return Scaffold(
            floatingActionButton: floatingActionButton,
            body: Row(
              children: [
                _AndroidNavigationRail(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: _AndroidNavigationBar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }
}

Widget? _toFab(BottomNavPrimaryAction? action) {
  if (action == null) return null;
  return FloatingActionButton.extended(
    onPressed: action.onPressed,
    icon: Icon(action.materialIcon),
    label: Text(action.label),
  );
}
