import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/main/main_destinations.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/platform_bottom_nav_bar.dart';
import 'package:flutter/material.dart';

/// Tabbed shell hosting the app's top-level destinations: wires
/// [AutoTabsRouter]'s active tab/selection to [PlatformBottomNavigationBar],
/// which then renders whichever platform-native bar/rail is appropriate.
@RoutePage()
final class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [HomeRoute(), NotificationRoute(), ProfileRoute()],
      builder: (context, child) {
        final tabsRouter = context.tabsRouter;
        return PlatformBottomNavigationBar(
          destinations: buildMainDestinations(),
          selectedIndex: tabsRouter.activeIndex,
          onDestinationSelected: tabsRouter.setActiveIndex,
          body: child,
        );
      },
    );
  }
}
