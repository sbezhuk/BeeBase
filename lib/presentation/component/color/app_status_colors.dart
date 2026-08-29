import 'package:flutter/material.dart';

/// Semantic feedback colors — validation errors and attention/warning
/// states today, room for success/info as they come up.
@immutable
final class AppStatusColors {
  const AppStatusColors({required this.error, required this.warning});

  final Color error;
  final Color warning;

  AppStatusColors copyWith({Color? error, Color? warning}) {
    return AppStatusColors(error: error ?? this.error, warning: warning ?? this.warning);
  }

  AppStatusColors lerp(AppStatusColors other, double t) {
    return AppStatusColors(
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
