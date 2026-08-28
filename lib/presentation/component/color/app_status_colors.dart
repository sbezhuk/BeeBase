import 'package:flutter/material.dart';

/// Semantic feedback colors — validation errors today, room for
/// warning/success/info as they come up.
@immutable
final class AppStatusColors {
  const AppStatusColors({required this.error});

  final Color error;

  AppStatusColors copyWith({Color? error}) {
    return AppStatusColors(error: error ?? this.error);
  }

  AppStatusColors lerp(AppStatusColors other, double t) {
    return AppStatusColors(error: Color.lerp(error, other.error, t)!);
  }
}
