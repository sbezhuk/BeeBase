import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
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

/// Page shell for iOS: a Liquid Glass navigation bar with a compact glass
/// back button (per the design brief, never the standard Material chevron
/// here) over a soft honey-tinted backdrop.
///
/// By default the app bar is the first item of one [CustomScrollView]
/// together with [slivers], so it scrolls away with the rest of the content
/// instead of staying pinned — [GlassAppBar] is used directly as a plain
/// sliver child rather than through [GlassScaffold], which would pin it to
/// the top of a Stack. The one exception is when [fadeEdges] is combined
/// with [showBackButton]: [FadingEdgeScrollView]'s `ShaderMask` forces its
/// entire child subtree onto an offscreen layer, which corrupts
/// `BackdropFilter`-based Liquid Glass rendering for anything nested inside
/// it — unconditionally, regardless of the mask's alpha at that pixel, so
/// even sitting at rest with no fade visually active is enough to corrupt
/// it. [GlassAppBar]'s `GlassButton`s can never be a `ShaderMask`
/// descendant, so in that combination the app bar is pulled out of the
/// scroll view and pinned as a fixed header above it instead — still safe
/// to build (no `BackdropFilter` involved) when [showBackButton] is
/// `false`, since that branch renders a plain title, not a [GlassAppBar].
///
/// Used two different ways, which need two different top-level wraps:
///
/// - Details/Form pages are pushed as their own root-level routes, so they
///   own the full screen: the scroll view is wrapped in `SafeArea(top:
///   false)` (the [GlassAppBar] sliver already pads its own top inset
///   internally) so the home indicator area at the bottom is respected too.
/// - A tab-root list page (e.g. the Apiaries tab) already lives inside
///   [MainPage]'s own `GlassScaffold` (the tab shell), which reserves the
///   bottom nav bar space itself. [showBackButton] is `false` only for that
///   tab-root case, and doubles as the signal to render a plain inline title
///   sliver (with its own top-only [SafeArea]) instead of a [GlassAppBar],
///   with no outer [SafeArea] wrap that would double-pad the bottom.
final class IosAppScaffold extends StatelessWidget {
  // Matches GlassTabBar.minimizable's own default `barHeight` (see
  // MainPage's IosBottomNavigationBar, which never overrides it) — there is
  // no shared constant exported by liquid_glass_widgets for this. The
  // floating tab bar lives in MainPage's own GlassScaffold, which uses
  // `extendBody: true` (its default), so it overlays tab content rather
  // than reserving layout space for it, and relies on real content sitting
  // behind its `BackdropFilter` blur to look like glass rather than an
  // opaque panel — so the tab-root list must keep painting its full height
  // behind the bar (never shrink the CustomScrollView's own box for this),
  // while still only letting the user actually *scroll* that far when
  // [hasContent] says there's a real last item to clear the bar for.
  //
  // This has to be a trailing sliver (SliverToBoxAdapter appended after
  // [slivers]), gated on [hasContent], rather than a box-level Padding or a
  // SliverPadding inside the sliver list:
  //  - A box-level Padding shrinks the CustomScrollView's own render size,
  //    which also shrinks what it paints — the empty/loading/error states
  //    (a SliverFillRemaining, e.g. apiary_list_loaded_view.dart) would
  //    stop short of the true screen bottom, leaving nothing but the bare
  //    background gradient behind the bar instead of the empty-state
  //    content, which is exactly the "flat, opaque-looking bar" regression
  //    this comment is here to warn against re-introducing.
  //  - A SliverPadding's reduced remainingPaintExtent only ever accounts
  //    for the padding *before* its child in scroll order — trailing
  //    padding is laid out after and is invisible to an earlier sibling —
  //    so it wouldn't stop a SliverFillRemaining from filling the entire
  //    viewport and then adding this clearance as genuine extra scroll
  //    extent on top of that regardless of [hasContent].
  // A plain trailing SliverToBoxAdapter has neither problem: it never
  // touches the CustomScrollView's box size (full-height paint, and thus
  // the "content/background behind the glass bar" look, is preserved
  // unconditionally), and it only ever contributes real scroll extent when
  // [hasContent] includes it — a SliverFillRemaining upstream already
  // naturally produces zero extra scroll extent on its own (nothing
  // artificial follows it) whenever it's the state in play, i.e. whenever
  // [hasContent] is false, exactly matching intent without special-casing.
  static const double _floatingTabBarClearance = 64;

  const IosAppScaffold({
    required this.title,
    required this.slivers,
    required this.onBack,
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
  final VoidCallback onBack;
  final bool showBackButton;
  final AppScaffoldAction? trailingAction;
  final Future<void> Function()? onRefresh;
  final bool fadeEdges;
  final ScrollController? controller;

  // Only meaningful for the tab-root case (showBackButton: false) — whether
  // [slivers] is currently a real, populated list rather than an
  // empty/loading/error placeholder. Callers whose slivers never render a
  // SliverFillRemaining-style placeholder can safely leave this at its
  // default; see _floatingTabBarClearance's doc for what it controls.
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The slab-serif used for every other title in the app (see AppFont) —
    // GlassAppBar/CupertinoNavigationBar otherwise default to the system
    // font, which reads as generic rather than branded.
    final titleStyle = TextStyle(fontFamily: AppFont.titleBold, fontSize: 19, color: colors.text.primary);

    final Widget appBarContent;
    if (!showBackButton) {
      final action = trailingAction;
      appBarContent = SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.sm, context.spacing.md, context.spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: titleStyle.copyWith(fontSize: 30, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (action != null)
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
        ),
      );
    } else {
      final action = trailingAction;
      appBarContent = GlassAppBar(
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
          label: 'core.common.back'.tr(),
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
      );
    }

    // ShaderMask (via FadingEdgeScrollView) corrupts a GlassButton nested
    // anywhere inside it, unconditionally — see the class doc comment. Only
    // the showBackButton branch above ever builds a GlassAppBar/GlassButton,
    // so pinning is only needed there; the plain-title branch has no
    // BackdropFilter involved and stays a normal scrolling sliver either way.
    final pinAppBar = showBackButton && fadeEdges;

    Widget scrollView = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        if (!pinAppBar) SliverToBoxAdapter(child: appBarContent),
        ...slivers,
        // Tab-root case with real content only — see _floatingTabBarClearance's
        // doc for why this must be a plain trailing sliver, and why it's
        // gated on hasContent rather than always present.
        if (!showBackButton && hasContent)
          SliverToBoxAdapter(child: SizedBox(height: _floatingTabBarClearance + MediaQuery.paddingOf(context).bottom)),
      ],
    );
    if (fadeEdges) scrollView = FadingEdgeScrollView(child: scrollView);
    final refresh = onRefresh;
    final Widget content = refresh == null ? scrollView : RefreshIndicator.adaptive(onRefresh: refresh, child: scrollView);
    Widget body = pinAppBar
        ? Column(
            children: [
              appBarContent,
              Expanded(child: content),
            ],
          )
        : content;
    // Detail/Form routes own the full screen, so the home indicator area at
    // the bottom needs an explicit SafeArea; the tab-root list page already
    // sits inside MainPage's own scaffold, which reserves that space itself.
    if (showBackButton) body = SafeArea(top: false, child: body);

    // No background painted here — AppScaffold paints one shared
    // HoneyGradientBackground behind this widget, full-bleed and unclipped
    // by its SafeArea, so it stays a single continuous gradient rather than
    // a second one computed over this widget's own (safe-area-inset) height.
    return Material(type: MaterialType.transparency, child: body);
  }
}
