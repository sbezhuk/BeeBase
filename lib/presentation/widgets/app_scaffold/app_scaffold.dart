import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/widgets/app_scaffold/android_app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/presentation/widgets/app_scaffold/ios_app_scaffold.dart';
import 'package:flutter/material.dart';

/// Platform-forked page shell shared by every list/details/form screen in
/// the app: Liquid Glass chrome on iOS ([IosAppScaffold]), Material 3 on
/// Android ([AndroidAppScaffold]). [slivers] content is passed through
/// untouched so layout and business logic never fork — only the surrounding
/// chrome does.
///
/// One shared class rather than a per-feature copy (there used to be an
/// `ApiaryScaffold` and a near-identical `HiveScaffold`) — a feature-specific
/// scaffold class only duplicates this chrome and risks drifting out of sync
/// with it.
final class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.slivers,
    this.showBackButton = true,
    this.trailingAction,
    this.onRefresh,
    this.fadeEdges = false,
    this.controller,
    super.key,
  });

  final String title;
  final List<Widget> slivers;
  final bool showBackButton;
  final AppScaffoldAction? trailingAction;
  final Future<void> Function()? onRefresh;
  final bool fadeEdges;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => IosAppScaffold(
        title: title,
        slivers: slivers,
        showBackButton: showBackButton,
        trailingAction: trailingAction,
        onRefresh: onRefresh,
        fadeEdges: fadeEdges,
        controller: controller,
        onBack: () => context.router.maybePop(),
      ),
      _ => AndroidAppScaffold(
        title: title,
        slivers: slivers,
        showBackButton: showBackButton,
        trailingAction: trailingAction,
        onRefresh: onRefresh,
        fadeEdges: fadeEdges,
        controller: controller,
      ),
    };
  }
}
