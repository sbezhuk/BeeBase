import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/connectivity/connectivity_banner.dart';
import 'package:beebase/presentation/main/main_destinations.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/sync/offline_sync_banner.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_primary_action.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/platform_bottom_nav_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tabbed shell hosting the app's top-level destinations: wires
/// [AutoTabsRouter]'s active tab/selection to [PlatformBottomNavigationBar],
/// which then renders whichever platform-native bar/rail is appropriate.
@RoutePage()
final class MainPage extends StatelessWidget {
  const MainPage({super.key});

  // Index of ApiaryListRoute in the [routes] list below — kept in sync
  // manually since AutoTabsRouter exposes only the active index, not the
  // route itself.
  static const _apiariesTabIndex = 1;

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [HomeRoute(), ApiaryListRoute(), ProfileRoute()],
      builder: (context, child) {
        final tabsRouter = context.tabsRouter;
        final isApiariesTab = tabsRouter.activeIndex == _apiariesTabIndex;
        return PlatformBottomNavigationBar(
          destinations: buildMainDestinations(),
          selectedIndex: tabsRouter.activeIndex,
          onDestinationSelected: tabsRouter.setActiveIndex,
          primaryAction: isApiariesTab
              ? BottomNavPrimaryAction(
                  label: 'apiary.list.addApiary'.tr(),
                  materialIcon: Icons.add,
                  cupertinoIcon: CupertinoIcons.add,
                  // ApiaryFormRoute is a root-level route, not nested under
                  // this tab, so it's pushed via the root router. A
                  // successful create reaches the list via
                  // ApiaryListRefreshNotifier, so nothing to await here.
                  onPressed: () => context.router.root.push(ApiaryFormRoute()),
                )
              : null,
          body: Column(
            children: [
              const ConnectivityBanner(),
              const OfflineSyncBanner(),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
