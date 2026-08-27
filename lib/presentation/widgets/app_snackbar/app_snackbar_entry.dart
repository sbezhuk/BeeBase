import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:flutter/widgets.dart';

/// One queued toast in [AppSnackBarController]'s stack: everything
/// [AppSnackBarStackItem] needs to render and auto-dismiss itself, keyed by
/// [id] so the controller can remove exactly this entry later.
final class AppSnackBarEntry {
  AppSnackBarEntry({
    required this.message,
    required this.variant,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
  }) : id = UniqueKey();

  final Key id;
  final String message;
  final AppSnackBarVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
}
