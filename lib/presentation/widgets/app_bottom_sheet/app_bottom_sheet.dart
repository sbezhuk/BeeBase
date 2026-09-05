import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

part 'app_sheet_button.dart';

/// Shows [builder]'s content as a modal bottom sheet with a transparent
/// barrier background, so the caller's own chrome (typically
/// [AppBottomSheetCard]) paints the actual surface instead of Flutter's
/// default one. The one presentation mechanism behind every bottom sheet in
/// the app — [showConfirmationSheet] and [showAppDatePicker] both build on
/// this rather than calling `showModalBottomSheet` directly, so any future
/// themed sheet starts from the same place and reads as the same component
/// family.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

/// The app's one bottom-sheet "card" chrome: a honey-bordered, rounded,
/// opaque surface with a drag-indicator pill, floating with [Spacing.sm]
/// margin off the screen edges. Shared by [ConfirmationSheet] and the date
/// picker so every bottom sheet in the app looks and feels like the same
/// component — not a separate styling system per feature.
final class AppBottomSheetCard extends StatelessWidget {
  const AppBottomSheetCard({
    required this.child,
    this.showDragHandle = true,
    super.key,
  });

  final Widget child;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(spacing.sm),
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.sm,
          spacing.lg,
          spacing.lg,
        ),
        decoration: BoxDecoration(
          color: colors.surface.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.honey.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle)
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(bottom: spacing.md),
                decoration: BoxDecoration(
                  color: colors.honey.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
