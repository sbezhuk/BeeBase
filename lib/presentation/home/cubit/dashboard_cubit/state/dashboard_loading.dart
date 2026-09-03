part of '../dashboard_cubit.dart';

/// First load only, before anything has ever resolved — drives a
/// full-screen spinner so no partial/incorrect stats render mid-load.
final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}
