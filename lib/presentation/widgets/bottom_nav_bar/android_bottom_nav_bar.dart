import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
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
    super.key,
  });

  final List<BottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _expandedLayoutBreakpoint) {
          return Scaffold(
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
        );
      },
    );
  }
}
