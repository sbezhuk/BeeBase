import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/component/honey_gradient_background.dart';
import 'package:beebase/presentation/widgets/fading_edge_scroll_view/fading_edge_scroll_view.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        AlwaysScrollableScrollPhysics,
        ClampingScrollPhysics,
        CustomScrollView,
        Material,
        MaterialType,
        RefreshIndicator,
        SliverToBoxAdapter;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Apiary page shell for iOS: a Liquid Glass navigation bar with a compact
/// glass back button (per the design brief, never the standard Material
/// chevron here) over a soft honey-tinted backdrop. The app bar is always
/// the first item of one [CustomScrollView] together with [slivers], so it
/// scrolls away with the rest of the content instead of staying pinned —
/// [GlassAppBar] is used directly as a plain sliver child rather than
/// through [GlassScaffold], which would pin it to the top of a Stack.
///
/// Used two different ways, which need two different top-level wraps:
///
/// - Details/Form are pushed as their own root-level routes, so they own the
///   full screen: the scroll view is wrapped in `SafeArea(top: false)` (the
///   [GlassAppBar] sliver already pads its own top inset internally) so the
///   home indicator area at the bottom is respected too.
/// - The list page is tab *content* — it already lives inside [MainPage]'s
///   own `GlassScaffold` (the tab shell), which reserves the bottom nav bar
///   space itself. [showBackButton] is `false` only for that tab-root case,
///   and doubles as the signal to render a plain inline title sliver (with
///   its own top-only [SafeArea]) instead of a [GlassAppBar], with no outer
///   [SafeArea] wrap that would double-pad the bottom.
final class IosApiaryScaffold extends StatelessWidget {
  // Matches GlassTabBar.minimizable's own default `barHeight` (see
  // MainPage's IosBottomNavigationBar, which never overrides it) — there is
  // no shared constant exported by liquid_glass_widgets for this. The
  // floating tab bar lives in MainPage's own GlassScaffold, which uses
  // `extendBody: true` (its default), so it overlays tab content rather
  // than reserving layout space for it — the tab-root list has to add this
  // clearance itself so its last item can still scroll clear of the bar.
  static const double _floatingTabBarClearance = 64;

  const IosApiaryScaffold({
    required this.title,
    required this.slivers,
    required this.onBack,
    this.showBackButton = true,
    this.trailingAction,
    this.onRefresh,
    this.fadeEdges = false,
    this.controller,
    super.key,
  });

  final String title;
  final List<Widget> slivers;
  final VoidCallback onBack;
  final bool showBackButton;
  final ApiaryScaffoldAction? trailingAction;
  final Future<void> Function()? onRefresh;
  final bool fadeEdges;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The slab-serif used for every other title in the app (see AppFont) —
    // GlassAppBar/CupertinoNavigationBar otherwise default to the system
    // font, which reads as generic rather than branded.
    final titleStyle = TextStyle(fontFamily: AppFont.titleBold, fontSize: 19, color: colors.text.primary);

    final Widget appBarSliver;
    if (!showBackButton) {
      appBarSliver = SliverToBoxAdapter(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.sm, context.spacing.md, context.spacing.sm),
            child: Text(
              title,
              style: titleStyle.copyWith(fontSize: 30, height: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    } else {
      final action = trailingAction;
      appBarSliver = SliverToBoxAdapter(
        child: GlassAppBar(
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: Text(title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // iconColor is set explicitly on both nav buttons rather than left
          // to GlassButton's brightness-based default (plain black/white) —
          // the brand's honey-gold accent on the glass surface is the
          // signature visual cue tying navigation back to the beekeeping
          // identity.
          leading: Semantics(
            button: true,
            label: 'apiary.common.back'.tr(),
            child: GlassButton(
              icon: const Icon(CupertinoIcons.back),
              iconColor: colors.brand.primary,
              onTap: onBack,
              width: 36,
              height: 36,
              iconSize: 18,
            ),
          ),
          actions: action == null
              ? null
              : [
                  Semantics(
                    button: true,
                    label: action.label,
                    child: GlassButton(
                      icon: Icon(action.cupertinoIcon),
                      iconColor: colors.brand.primary,
                      onTap: action.onPressed,
                      width: 36,
                      height: 36,
                      iconSize: 18,
                    ),
                  ),
                ],
        ),
      );
    }

    Widget scrollView = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        appBarSliver,
        ...slivers,
        // Tab-root case only: the floating glass tab bar overlays content
        // instead of reserving space for it (see _floatingTabBarClearance),
        // so the last item needs real bottom padding to scroll clear of it.
        if (!showBackButton)
          SliverToBoxAdapter(child: SizedBox(height: _floatingTabBarClearance + MediaQuery.paddingOf(context).bottom)),
      ],
    );
    if (fadeEdges) scrollView = FadingEdgeScrollView(child: scrollView);
    final refresh = onRefresh;
    Widget body = refresh == null ? scrollView : RefreshIndicator.adaptive(onRefresh: refresh, child: scrollView);
    // Detail/Form routes own the full screen, so the home indicator area at
    // the bottom needs an explicit SafeArea; the tab-root list page already
    // sits inside MainPage's own scaffold, which reserves that space itself.
    if (showBackButton) body = SafeArea(top: false, child: body);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: HoneyGradientBackground()),
          body,
        ],
      ),
    );
  }
}
