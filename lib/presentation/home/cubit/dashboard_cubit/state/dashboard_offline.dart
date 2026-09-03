part of '../dashboard_cubit.dart';

/// No network connectivity — the Dashboard is online-only, so nothing is
/// fetched or shown from any local cache while in this state.
final class DashboardOffline extends DashboardState {
  const DashboardOffline();
}
