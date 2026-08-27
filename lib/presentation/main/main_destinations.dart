import 'package:beebase/presentation/widgets/bottom_nav_bar/bottom_nav_destination.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Top-level destinations for [MainPage]'s [PlatformBottomNavigationBar].
///
/// A function rather than a top-level constant so labels are resolved
/// through `.tr()` at build time, not cached from whatever locale was active
/// the first time this library was loaded.
List<BottomNavDestination> buildMainDestinations() {
  return [
    BottomNavDestination(
      label: 'main.nav.home'.tr(),
      materialIcon: Icons.home_outlined,
      materialIconSelected: Icons.home,
      cupertinoIcon: CupertinoIcons.house,
      cupertinoIconSelected: CupertinoIcons.house_fill,
    ),
    BottomNavDestination(
      label: 'main.nav.apiaries'.tr(),
      materialIcon: Icons.hive_outlined,
      materialIconSelected: Icons.hive,
      cupertinoIcon: CupertinoIcons.square_grid_2x2,
      cupertinoIconSelected: CupertinoIcons.square_grid_2x2_fill,
    ),
    BottomNavDestination(
      label: 'main.nav.profile'.tr(),
      materialIcon: Icons.person_outline,
      materialIconSelected: Icons.person,
      cupertinoIcon: CupertinoIcons.person,
      cupertinoIconSelected: CupertinoIcons.person_fill,
    ),
  ];
}
