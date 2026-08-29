import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/apiary/widget/android_apiary_scaffold.dart';
import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/presentation/apiary/widget/ios_apiary_scaffold.dart';
import 'package:flutter/material.dart';

/// Platform-forked page shell shared by every Apiary screen: Liquid Glass
/// chrome on iOS ([IosApiaryScaffold]), Material 3 on Android
/// ([AndroidApiaryScaffold]). [slivers] content is passed through untouched
/// so layout and business logic never fork — only the surrounding chrome
/// does.
///
/// The app bar (title, back button, [trailingAction]) is built by the
/// platform shell as the first item of one scroll view, ahead of [slivers] —
/// it scrolls away with the rest of the content rather than staying fixed.
/// [onRefresh] wraps that scroll view in pull-to-refresh when provided;
/// [fadeEdges] fades content near the top/bottom edges as it scrolls under
/// them (see [FadingEdgeScrollView]).
final class ApiaryScaffold extends StatelessWidget {
  const ApiaryScaffold({
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
  final ApiaryScaffoldAction? trailingAction;
  final Future<void> Function()? onRefresh;
  final bool fadeEdges;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => IosApiaryScaffold(
        title: title,
        slivers: slivers,
        showBackButton: showBackButton,
        trailingAction: trailingAction,
        onRefresh: onRefresh,
        fadeEdges: fadeEdges,
        controller: controller,
        onBack: () => context.router.maybePop(),
      ),
      _ => AndroidApiaryScaffold(
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
