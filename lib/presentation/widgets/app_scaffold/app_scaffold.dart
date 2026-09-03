import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/component/honey_gradient_background.dart';
import 'package:beebase/presentation/widgets/app_scaffold/android_app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/presentation/widgets/app_scaffold/ios_app_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.hasContent = true,
    super.key,
  });

  final String title;
  final List<Widget> slivers;
  final bool showBackButton;
  final AppScaffoldAction? trailingAction;
  final Future<void> Function()? onRefresh;
  final bool fadeEdges;
  final ScrollController? controller;

  // See IosAppScaffold.hasContent — only meaningful there (iOS's floating
  // glass tab bar needs it); Android's bottomNavigationBar reserves its own
  // layout space instead of overlaying content, so AndroidAppScaffold has
  // no equivalent concept and this is simply not forwarded to it.
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    // `.tr()` (used throughout `slivers`/`title` by every caller) reads the
    // active locale from a global singleton, not from `BuildContext` — none
    // of that establishes a rebuild dependency on its own. AutoRoute's
    // Navigator, being Pages-API-based, does not rebuild an already-pushed
    // route's content just because an ancestor above it (like `MaterialApp`)
    // rebuilds with a new locale — only a widget that explicitly depends on
    // `EasyLocalization`'s `InheritedWidget` gets told directly. Reading
    // `context.locale` here registers exactly that dependency once, for
    // every screen built through this shared shell, so switching language
    // refreshes already-open screens immediately instead of only the next
    // one pushed.
    context.locale;
    final body = switch (Theme.of(context).platform) {
      TargetPlatform.iOS => IosAppScaffold(
        title: title,
        slivers: slivers,
        showBackButton: showBackButton,
        trailingAction: trailingAction,
        onRefresh: onRefresh,
        fadeEdges: fadeEdges,
        controller: controller,
        hasContent: hasContent,
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

    // HoneyGradientBackground is painted once here, full-bleed and
    // unclipped by SafeArea, so it's computed over the true screen height
    // and reaches edge-to-edge behind the status bar. IosAppScaffold and
    // AndroidAppScaffold are transparent passthroughs (no background of
    // their own) precisely so this single gradient always shows through
    // — painting a second, independently-sized gradient inside the
    // SafeArea-inset `body` would produce a visible seam where the two
    // gradients (computed over different heights) meet. SafeArea only
    // insets `body`'s interactive content; GlassAppBar/SliverAppBar still
    // self-account for the top inset internally, which is a no-op once
    // SafeArea has already consumed it — see their own doc comments.
    return Stack(
      children: [
        const Positioned.fill(child: HoneyGradientBackground()),
        SafeArea(
          bottom: false,
          child: AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.dark, child: body),
        ),
      ],
    );
  }
}
