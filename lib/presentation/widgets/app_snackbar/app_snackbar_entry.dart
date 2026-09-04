import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:flutter/widgets.dart';

/// One queued toast/banner in [AppSnackBarController]'s stack: everything
/// [AppSnackBarStackItem] needs to render and (optionally) auto-dismiss
/// itself, keyed by [id] so the controller can remove or update exactly this
/// entry later.
///
/// [tag] opts an entry out of the default "one push, one toast" behavior:
/// pushing another entry with the same [tag] replaces this one in place
/// (same [id], no re-entrance animation) instead of stacking a duplicate —
/// see [AppSnackBarController.enqueue]. This is what lets a long-lived,
/// state-driven notification reuse the same queue as ephemeral toasts:
/// it re-shows under its own tag every time its backing state changes, and
/// calls [AppSnackBar.hide] to remove itself.
///
/// [duration] is nullable — `null` means the entry stays until dismissed
/// (manually or via [AppSnackBar.hide]), which persistent/tagged entries
/// should use since there's no fixed lifetime to expire on.
final class AppSnackBarEntry {
  AppSnackBarEntry({
    required this.message,
    required this.variant,
    this.description,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.isLoading = false,
    this.duration = const Duration(seconds: 4),
    this.tag,
    Key? id,
  }) : id = id ?? UniqueKey();

  final Key id;
  final String? tag;
  final String message;
  final String? description;
  final AppSnackBarVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool isLoading;
  final Duration? duration;

  /// Same content as this entry, but keeping [newId] instead of its own —
  /// used by [AppSnackBarController.enqueue] to update a tagged entry in
  /// place without disturbing [AppSnackBarStackItem]'s widget identity.
  AppSnackBarEntry copyWithId(Key newId) {
    return AppSnackBarEntry(
      message: message,
      variant: variant,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismiss: onDismiss,
      isLoading: isLoading,
      duration: duration,
      tag: tag,
      id: newId,
    );
  }
}
