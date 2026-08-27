import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_controller.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_stack_item.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:flutter/material.dart';

/// Root-level overlay content for [AppSnackBarController]: renders every
/// active toast as a single deck pinned to the bottom of the screen, clear
/// of the keyboard and the safe area. The newest entry sits at the front at
/// full size; older ones are handed their distance from the front (see
/// [AppSnackBarStackItem.depth]) so they can recede behind it.
final class AppSnackBarStack extends StatelessWidget {
  const AppSnackBarStack({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder(
      valueListenable: AppSnackBarController.entries,
      builder: (context, entries, _) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset + spacing.sm,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < entries.length; i++)
                  AppSnackBarStackItem(
                    key: entries[i].id,
                    entry: entries[i],
                    depth: entries.length - 1 - i,
                    onRemoved: AppSnackBarController.remove,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
