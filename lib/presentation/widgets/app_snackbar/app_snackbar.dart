import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_controller.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_entry.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:flutter/material.dart';

/// Entry point for the app's custom snack bar: shows [AppSnackBarCard]s in a
/// root-level overlay stack (see [AppSnackBarController]) instead of going
/// through [ScaffoldMessenger], so several calls to [show] in quick
/// succession stack on top of one another rather than replacing each other.
/// Call [show] wherever the plain
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` pattern would
/// otherwise be used.
///
/// Pass [tag] to opt into a persistent, updatable notification instead of a
/// one-off toast: calling [show] again with the same [tag] updates that
/// entry in place (e.g. swapping [isLoading] on while work is in flight)
/// rather than stacking a new one, and [hide] removes it. Persistent entries
/// should also pass `duration: null` (the default when [tag] isn't used is
/// a 4-second auto-dismiss) since there's no fixed lifetime to expire on —
/// see `OfflineSyncBanner` for a full example of this pattern.
abstract final class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    String? description,
    AppSnackBarVariant variant = AppSnackBarVariant.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
    bool isLoading = false,
    Duration? duration = const Duration(seconds: 4),
    String? tag,
  }) {
    AppSnackBarController.enqueue(
      context,
      AppSnackBarEntry(
        message: message,
        description: description,
        variant: variant,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: onDismiss,
        isLoading: isLoading,
        duration: duration,
        tag: tag,
      ),
    );
  }

  /// Removes the persistent entry currently showing under [tag] (see
  /// [show]'s `tag` param), if any. No-op if none is showing.
  static void hide(String tag) {
    AppSnackBarController.removeByTag(tag);
  }
}
