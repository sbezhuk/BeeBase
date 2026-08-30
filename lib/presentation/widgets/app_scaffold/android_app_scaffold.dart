import 'package:beebase/presentation/component/honey_gradient_background.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/presentation/widgets/fading_edge_scroll_view/fading_edge_scroll_view.dart';
import 'package:flutter/material.dart';

/// Page shell for Android: a [SliverAppBar] leading one [CustomScrollView]
/// together with [slivers], matching the platform's own back-navigation
/// affordance rather than borrowing the iOS glass treatment.
/// `pinned`/`floating`/`snap` are all left `false`, so the bar scrolls away
/// with the rest of the content instead of staying fixed.
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
    Widget scrollView = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          automaticallyImplyLeading: showBackButton,
          actions: action == null
              ? null
              : [
                  IconButton(
                    icon: Icon(action.materialIcon),
                    tooltip: action.label,
                    onPressed: action.onPressed,
                  ),
                ],
          pinned: false,
          floating: false,
          snap: false,
        ),
        ...slivers,
      ],
    );
    if (fadeEdges) scrollView = FadingEdgeScrollView(child: scrollView);
    final refresh = onRefresh;
    final body = refresh == null
        ? scrollView
        : RefreshIndicator.adaptive(onRefresh: refresh, child: scrollView);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HoneyGradientBackground()),
          // The SliverAppBar already accounts for the top status-bar inset
          // itself (the same as when it sits directly in a Scaffold.body
          // with no Scaffold.appBar), so only the bottom needs SafeArea here.
          SafeArea(top: false, child: body),
        ],
      ),
    );
  }
}
