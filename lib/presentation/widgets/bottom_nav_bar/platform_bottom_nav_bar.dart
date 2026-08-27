import 'package:beebase/presentation/widgets/bottom_nav_bar/android_bottom_nav_bar.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_primary_action.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/ios_bottom_nav_bar.dart';
import 'package:flutter/material.dart';

/// Top-level navigation shell: picks the platform-native tab bar for the
/// running OS and hosts [body] (the current tab's content) above/behind it.
///
/// iOS gets a floating Liquid-Glass-style bar ([IosBottomNavigationBar]);
/// everything else gets an adaptive Material 3 bar/rail
/// ([AndroidBottomNavigationBar]). Both share the same [destinations] model,
/// selection state, and callback — only the presentation differs.
final class PlatformBottomNavigationBar extends StatelessWidget {
  const PlatformBottomNavigationBar({
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

  /// Optional platform-styled primary action (e.g. "create") shown
  /// alongside the bar. See [BottomNavPrimaryAction].
  final BottomNavPrimaryAction? primaryAction;

  @override
  Widget build(BuildContext context) {
    void selectIfEnabled(int index) {
      if (destinations[index].enabled) onDestinationSelected(index);
    }

    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => IosBottomNavigationBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: selectIfEnabled,
        body: body,
        primaryAction: primaryAction,
      ),
      _ => AndroidBottomNavigationBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: selectIfEnabled,
        body: body,
        primaryAction: primaryAction,
      ),
    };
  }
}
