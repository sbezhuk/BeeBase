part of '../dashboard_cubit.dart';

/// The device has no connectivity. Unlike Apiaries/Hives/Inspections, the
/// Dashboard never falls back to cached/local data — it's reachable from any
/// other state the instant [DashboardCubit] detects the device went offline,
/// and left only via [DashboardCubit.loadDashboard] once connectivity is
/// confirmed again.
final class DashboardOffline extends DashboardState {
  const DashboardOffline();
}
