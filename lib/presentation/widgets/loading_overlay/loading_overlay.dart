import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Dims [child] and centers an adaptive spinner over it while [isLoading] is
/// true. Used by list pages (apiary/hive/inspection) so a fetch in flight is
/// always visible to the user — including a refresh triggered from
/// elsewhere in the app (e.g. a sibling list's `RefreshNotifier`), which
/// pull-to-refresh's own built-in spinner never surfaces since nothing
/// pulled the list down by hand.
final class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({required this.isLoading, required this.child, super.key});

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: context.colors.surface.scrim,
              child: const Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
      ],
    );
  }
}
