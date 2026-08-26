part of '../android_bottom_nav_bar.dart';

/// Material Symbol for a destination, with [Badge.count] overlaid when it
/// carries a badge. Shared by [_AndroidNavigationBar] and
/// [_AndroidNavigationRail] so both surfaces render badges identically.
final class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.destination, required this.selected});

  final BottomNavDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? destination.materialIconSelected : destination.materialIcon);
    final badgeCount = destination.badgeCount;
    if (badgeCount == null || badgeCount <= 0) return icon;
    return Badge.count(count: badgeCount, child: icon);
  }
}
