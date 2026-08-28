import 'dart:ui' show Tristate;

import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/android_bottom_nav_bar.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_primary_action.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/ios_bottom_nav_bar.dart';
import 'package:beebase/presentation/widgets/bottom_nav_bar/platform_bottom_nav_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<BottomNavDestination> destinations({int? badgeCount, bool thirdEnabled = true}) {
    return [
      BottomNavDestination(
        label: 'Home',
        materialIcon: Icons.home_outlined,
        materialIconSelected: Icons.home,
        cupertinoIcon: CupertinoIcons.house,
        cupertinoIconSelected: CupertinoIcons.house_fill,
      ),
      BottomNavDestination(
        label: 'Alerts',
        materialIcon: Icons.notifications_outlined,
        materialIconSelected: Icons.notifications,
        cupertinoIcon: CupertinoIcons.bell,
        cupertinoIconSelected: CupertinoIcons.bell_fill,
        badgeCount: badgeCount,
      ),
      BottomNavDestination(
        label: 'More',
        semanticLabel: 'More options',
        materialIcon: Icons.more_horiz,
        materialIconSelected: Icons.more_horiz,
        cupertinoIcon: CupertinoIcons.ellipsis,
        enabled: thirdEnabled,
      ),
    ];
  }

  Future<void> pumpNavBar(
    WidgetTester tester, {
    required TargetPlatform platform,
    required List<BottomNavDestination> destinations,
    required int selectedIndex,
    required ValueChanged<int> onDestinationSelected,
    Brightness brightness = Brightness.dark,
    BottomNavPrimaryAction? primaryAction,
    // A phone-width viewport by default — the framework's default test
    // surface (800x600) is already past the tablet breakpoint, which would
    // silently exercise the NavigationRail branch instead of the bar one.
    Size viewSize = const Size(390, 844),
  }) {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform, brightness: brightness, extensions: [const AppColor.dark()]),
        home: PlatformBottomNavigationBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          primaryAction: primaryAction,
          body: const SizedBox.expand(),
        ),
      ),
    );
  }

  group('iOS platform', () {
    testWidgets('renders the Liquid-Glass tab bar with one item per destination', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
      );

      expect(find.byType(IosBottomNavigationBar), findsOneWidget);
      expect(find.byType(AndroidBottomNavigationBar), findsNothing);
      // GlassTabBar mounts both the resting and selected weight/icon
      // variants at once to cross-fade between them, so each label/icon
      // renders twice — assert presence, not a single instance.
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Alerts'), findsWidgets);
      expect(find.text('More'), findsWidgets);
    });

    testWidgets('shows the selected destination as selected in semantics', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(),
        selectedIndex: 1,
        onDestinationSelected: (_) {},
      );

      final homeSemantics = tester.getSemantics(find.bySemanticsLabel('Home'));
      final alertsSemantics = tester.getSemantics(find.bySemanticsLabel(RegExp('Alerts')));
      expect(homeSemantics.flagsCollection.isSelected, Tristate.isFalse);
      expect(alertsSemantics.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets('invokes the callback when an enabled destination is tapped', (tester) async {
      var selected = -1;
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (index) => selected = index,
      );

      await tester.tap(find.text('Alerts').first);
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets('does not invoke the callback for a disabled destination', (tester) async {
      var callCount = 0;
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(thirdEnabled: false),
        selectedIndex: 0,
        onDestinationSelected: (_) => callCount++,
      );

      await tester.tap(find.text('More').first);
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('surfaces the badge count and folds it into semantics', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(badgeCount: 5),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
      );

      expect(find.text('5'), findsWidgets);
      // GlassTabBar excludes the icon/badge subtree from semantics and
      // speaks GlassTab.semanticLabel as the tab's one accessibility node,
      // so the badge count is folded into that label (see ios_bottom_nav_bar.dart).
      final tabSemantics = tester.getSemantics(find.bySemanticsLabel(RegExp('Alerts, 5 new')).first);
      expect(tabSemantics.label, contains('5'));
    });

    testWidgets('renders under the dark palette without error', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        brightness: Brightness.dark,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(IosBottomNavigationBar), findsOneWidget);
    });

    testWidgets('renders and invokes the primary action as an extra button', (tester) async {
      var tapped = false;
      await pumpNavBar(
        tester,
        platform: TargetPlatform.iOS,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        primaryAction: BottomNavPrimaryAction(
          label: 'Add',
          materialIcon: Icons.add,
          cupertinoIcon: CupertinoIcons.add,
          onPressed: () => tapped = true,
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('Add'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('Android platform', () {
    testWidgets('renders a Material 3 NavigationBar with one destination per entry', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
      );

      expect(find.byType(AndroidBottomNavigationBar), findsOneWidget);
      expect(find.byType(IosBottomNavigationBar), findsNothing);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 3);
    });

    testWidgets('reflects selectedIndex on the NavigationBar', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 2,
        onDestinationSelected: (_) {},
      );

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    testWidgets('invokes the callback when a destination is tapped', (tester) async {
      var selected = -1;
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (index) => selected = index,
      );

      await tester.tap(find.text('Alerts'));
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets('does not invoke the callback for a disabled destination', (tester) async {
      var callCount = 0;
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(thirdEnabled: false),
        selectedIndex: 0,
        onDestinationSelected: (_) => callCount++,
      );

      await tester.tap(find.text('More'));
      await tester.pump();

      expect(callCount, 0);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final thirdDestination = navBar.destinations[2] as NavigationDestination;
      expect(thirdDestination.enabled, isFalse);
    });

    testWidgets('shows a Material badge with the count', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(badgeCount: 7),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
      );

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('switches to a NavigationRail on expanded (tablet) widths', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        viewSize: const Size(1200, 800),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('renders under the dark palette without error', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        brightness: Brightness.dark,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AndroidBottomNavigationBar), findsOneWidget);
    });

    testWidgets('omits the FAB when no primary action is given', (tester) async {
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
      );

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('renders and invokes the primary action as a floating action button', (tester) async {
      var tapped = false;
      await pumpNavBar(
        tester,
        platform: TargetPlatform.android,
        destinations: destinations(),
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        primaryAction: BottomNavPrimaryAction(
          label: 'Add',
          materialIcon: Icons.add,
          cupertinoIcon: CupertinoIcons.add,
          onPressed: () => tapped = true,
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
