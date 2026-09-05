import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/statistics_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/dashboard_state.dart';
part 'state/dashboard_loading.dart';
part 'state/dashboard_loaded.dart';
part 'state/dashboard_offline.dart';
part 'state/dashboard_section.dart';
part 'mixin/dashboard_emitter.dart';

/// Dashboard/statistics screen (BEEB-24): fetches every section fresh from
/// statistics-service on load/refresh.
///
/// Stays current without a manual refresh (BEEB-31) by subscribing to the
/// same [ApiaryListRefreshNotifier]/[HiveListRefreshNotifier]/
/// [InspectionListRefreshNotifier] broadcasts the list/details cubits
/// already react to for their own screens — the writer emitters fire these
/// only after a create/update/delete actually succeeds, so a failed
/// mutation never triggers a refetch here. Only the sections a given
/// entity's stats are derived from are refetched, so e.g. an inspection
/// edit doesn't re-fetch apiary stats.
final class DashboardCubit extends Cubit<DashboardState> with DashboardEmitter {
  DashboardCubit({
    required this.statisticsReader,
    required this.apiaryReader,
    required this.hiveReader,
    required this.inspectionReader,
    required this.networkInfo,
    required this.apiaryRefreshNotifier,
    required this.hiveRefreshNotifier,
    required this.inspectionRefreshNotifier,
  }) : super(const DashboardLoading()) {
    _apiarySubscription = apiaryRefreshNotifier.onChanged.listen((_) => _refreshApiaryDerivedSections());
    _hiveSubscription = hiveRefreshNotifier.onChanged.listen((_) => _refreshApiaryDerivedSections());
    _inspectionSubscription = inspectionRefreshNotifier.onChanged.listen((_) => _refreshInspectionDerivedSections());
    // Reacts to a live connectivity drop while the Dashboard is open — the
    // Dashboard never shows cached data offline, so this switches straight
    // to DashboardOffline regardless of what was on screen. Coming back
    // online does *not* auto-reload; the offline view's retry button is the
    // only way back, per the online-only spec.
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((isOnline) {
      if (!isOnline) emit(const DashboardOffline());
    });
  }

  final IStatisticsReader statisticsReader;
  final IApiaryReader apiaryReader;
  final IHiveReader hiveReader;
  final IInspectionReader inspectionReader;
  final INetworkInfo networkInfo;
  final ApiaryListRefreshNotifier apiaryRefreshNotifier;
  final HiveListRefreshNotifier hiveRefreshNotifier;
  final InspectionListRefreshNotifier inspectionRefreshNotifier;
  StreamSubscription<void>? _apiarySubscription;
  StreamSubscription<void>? _hiveSubscription;
  StreamSubscription<void>? _inspectionSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Initial load — replaces the body with a full-screen spinner, or with
  /// DashboardOffline (no request made) when there's no connection.
  Future<void> loadDashboard() => emitLoad(statisticsReader, networkInfo);

  /// Pull-to-refresh — keeps the current sections visible while refetching.
  Future<void> refresh() => emitRefresh(statisticsReader, networkInfo);

  Future<void> retryOverview() => emitRetryOverview(statisticsReader);

  Future<void> retryApiaryStats() => emitRetryApiaryStats(statisticsReader);

  Future<void> retryInspectionStats() => emitRetryInspectionStats(statisticsReader);

  Future<void> retryRecentActivity() => emitRetryRecentActivity(statisticsReader);

  /// Reacts to [apiaryRefreshNotifier]/[hiveRefreshNotifier]: an apiary or
  /// hive create/edit/delete changes apiary/hive counts and hive
  /// distribution, which only the overview and apiary-stats sections are
  /// derived from. A no-op while the dashboard isn't [DashboardLoaded]
  /// (e.g. still on its initial load) — that in-flight/upcoming load
  /// already fetches fresh data.
  Future<void> _refreshApiaryDerivedSections() => Future.wait([retryOverview(), retryApiaryStats()]);

  /// Reacts to [inspectionRefreshNotifier]: an inspection create/edit/delete
  /// changes inspection counts and the recent-activity feed, which only the
  /// overview, inspection-stats, and recent-activity sections are derived
  /// from.
  Future<void> _refreshInspectionDerivedSections() =>
      Future.wait([retryOverview(), retryInspectionStats(), retryRecentActivity()]);

  /// Fetch-then-navigate passthroughs for the Dashboard's tap targets — the
  /// stats endpoints only return id+name for these, not the full entity the
  /// existing `*DetailsRoute`s need, so the tapped tile fetches it first.
  /// These don't touch [state]; the caller widget owns its own pending/error
  /// UI for the tap.
  Future<Either<Failure, Apiary>> fetchApiary(String id) => apiaryReader.getApiary(id);

  Future<Either<Failure, Hive>> fetchHive(String id) => hiveReader.getHive(id);

  Future<Either<Failure, Inspection>> fetchInspection({required String hiveId, required String id}) =>
      inspectionReader.getInspection(hiveId: hiveId, id: id);

  @override
  Future<void> close() {
    unawaited(_apiarySubscription?.cancel());
    unawaited(_hiveSubscription?.cancel());
    unawaited(_inspectionSubscription?.cancel());
    unawaited(_connectivitySubscription?.cancel());
    return super.close();
  }
}
