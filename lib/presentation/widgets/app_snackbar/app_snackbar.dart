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
abstract final class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarVariant variant = AppSnackBarVariant.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    AppSnackBarController.enqueue(
      context,
      AppSnackBarEntry(message: message, variant: variant, actionLabel: actionLabel, onAction: onAction, duration: duration),
    );
  }
}
