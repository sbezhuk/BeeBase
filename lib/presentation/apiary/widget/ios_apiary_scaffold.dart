import 'package:beebase/presentation/apiary/widget/apiary_glass_settings.dart';
import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Apiary page shell for iOS: a Liquid Glass navigation bar with a compact
/// glass back button (per the design brief, never the standard Material
/// chevron here) over a soft honey-tinted backdrop.
///
/// Used two different ways, which need two different layouts:
///
/// - Details/Form are pushed as their own root-level routes, so they own the
///   full screen and get a real [GlassScaffold] + [GlassAppBar].
/// - The list page is tab *content* — it already lives inside [MainPage]'s
///   own [GlassScaffold] (the tab shell). That outer scaffold reserves no
///   app-bar space for its body, so nesting a second [GlassScaffold] here
///   would recompute the top safe-area inset from scratch and its title row
///   would land right on top of the first list item. [showBackButton] is
///   `false` only for that tab-root case, and doubles as the signal to skip
///   the nested scaffold entirely in favor of a plain inline title row.
final class IosApiaryScaffold extends StatelessWidget {
  const IosApiaryScaffold({
    required this.title,
    required this.body,
    required this.onBack,
    this.showBackButton = true,
    this.trailingAction,
    super.key,
  });

  final String title;
  final Widget body;
  final VoidCallback onBack;
  final bool showBackButton;
  final ApiaryScaffoldAction? trailingAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The slab-serif used for every other title in the app (see AppFont) —
    // GlassAppBar/CupertinoNavigationBar otherwise default to the system
    // font, which reads as generic rather than branded.
    final titleStyle = TextStyle(fontFamily: AppFont.titleBold, fontSize: 19, color: colors.textPrimary);
    // Neither GlassScaffold nor this tab-root Column sits under a Scaffold,
    // so descendant Text widgets have no Material ancestor to pull their
    // DefaultTextStyle from — Flutter falls back to a debug style (yellow,
    // underlined) to flag that. type: transparency keeps it invisible while
    // still supplying that ancestor.
    if (!showBackButton) {
      return Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            SafeArea(
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
            Expanded(child: body),
          ],
        ),
      );
    }
    final action = trailingAction;
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        backgroundColor: colors.background,
        // GlassScaffold's default extendBody:true places the body via
        // Positioned.fill behind the app bar and relies on callers to insert
        // their own top spacer — it does NOT add one automatically despite
        // the class doc's "before/after" example implying otherwise. Rather
        // than duplicating that spacer math in every body, extendBody:false
        // makes the scaffold position the body in the space between the app
        // bar and the bottom safe area itself, which is simpler and correct.
        extendBody: false,
        appBar: GlassAppBar(
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: Text(title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          buttonSettings: apiaryGlassSettings(colors),
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
              iconColor: colors.primary,
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
                      iconColor: colors.primary,
                      onTap: action.onPressed,
                      width: 36,
                      height: 36,
                      iconSize: 18,
                    ),
                  ),
                ],
        ),
        // extendBody:false already clears the top (app bar) and status-bar
        // inset, but doesn't touch the bottom — there's no bottomBar here for
        // it to reserve space for, so the home indicator area needs SafeArea.
        body: SafeArea(top: false, child: body),
      ),
    );
  }
}
