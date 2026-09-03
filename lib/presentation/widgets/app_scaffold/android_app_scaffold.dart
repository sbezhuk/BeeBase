import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/presentation/widgets/fading_edge_scroll_view/fading_edge_scroll_view.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:flutter/material.dart';

/// Page shell for Android: a [SliverAppBar] leading one [CustomScrollView]
/// together with [slivers], matching the platform's own back-navigation
/// affordance rather than borrowing the iOS glass treatment.
/// `pinned`/`floating`/`snap` are all left `false`, so the bar scrolls away
/// with the rest of the content instead of staying fixed.
///
/// [showBackButton] `false` (tab-root pages, e.g. the Apiaries tab) skips
/// the [SliverAppBar] chrome entirely and renders a plain, large inline
/// heading instead — mirroring [IosAppScaffold]'s equivalent branch, rather
/// than falling back to a generic, compact Material toolbar for a case that
/// isn't really navigation chrome.
///
/// The one exception mirrors [IosAppScaffold]: when [fadeEdges] is combined
/// with [showBackButton], the back button/trailing action are persistent
/// chrome, not scrolling content, so fading them in and out with the list's
/// scroll position would read as broken. In that combination the app bar is
/// pulled out of the [CustomScrollView] (and its `ShaderMask`) and pinned as
/// a fixed header above it instead. Unlike the sliver [SliverAppBar], which
/// paints an opaque `ColorScheme.surface` background, the pinned [AppBar] is
/// given a transparent one so the shared `HoneyGradientBackground` still
/// shows through behind it rather than a solid bar suddenly appearing only
/// once the app bar is pinned.
final class AndroidAppScaffold extends StatelessWidget {
  const AndroidAppScaffold({
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
    final action = trailingAction;
    final actions = action == null
        ? null
        : [IconButton(icon: Icon(action.materialIcon), tooltip: action.label, onPressed: action.onPressed)];

    // See the class doc comment: only the showBackButton branch has
    // persistent chrome (a back button/trailing action) that shouldn't fade
    // with scroll position, so pinning is only needed there.
    final pinAppBar = showBackButton && fadeEdges;

    final Widget appBarSliver;
    if (!showBackButton) {
      appBarSliver = SliverToBoxAdapter(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.sm, context.spacing.md, context.spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFont.titleBold,
                      fontSize: 30,
                      height: 1.1,
                      color: context.colors.text.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (action != null) IconButton(icon: Icon(action.materialIcon), tooltip: action.label, onPressed: action.onPressed),
              ],
            ),
          ),
        ),
      );
    } else {
      appBarSliver = SliverAppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        automaticallyImplyLeading: showBackButton,
        actions: actions,
        pinned: false,
        floating: false,
        snap: false,
      );
    }

    Widget scrollView = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [if (!pinAppBar) appBarSliver, ...slivers],
    );
    if (fadeEdges) scrollView = FadingEdgeScrollView(child: scrollView);
    final refresh = onRefresh;
    final content = refresh == null ? scrollView : RefreshIndicator.adaptive(onRefresh: refresh, child: scrollView);
    final body = pinAppBar
        ? Column(
            children: [
              AppBar(
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                automaticallyImplyLeading: showBackButton,
                actions: actions,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              Expanded(child: content),
            ],
          )
        : content;
    // No background painted here — AppScaffold paints one shared
    // HoneyGradientBackground behind this widget, full-bleed and unclipped
    // by its SafeArea, so backgroundColor is transparent to let it show
    // through rather than painting a second gradient over this widget's own
    // (safe-area-inset) height.
    return Scaffold(
      backgroundColor: Colors.transparent,
      // The SliverAppBar already accounts for the top status-bar inset
      // itself (the same as when it sits directly in a Scaffold.body
      // with no Scaffold.appBar), so only the bottom needs SafeArea here.
      body: SafeArea(top: false, child: body),
    );
  }
}
