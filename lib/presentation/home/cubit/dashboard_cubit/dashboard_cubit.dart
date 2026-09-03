import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/services/connectivity_service.dart';
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
import 'package:beebase/utils/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/dashboard_state.dart';
part 'state/dashboard_loading.dart';
part 'state/dashboard_offline.dart';
part 'state/dashboard_loaded.dart';
part 'state/dashboard_section.dart';
part 'mixin/dashboard_emitter.dart';

/// Online-only Dashboard/statistics screen (BEEB-24): fetches every section
/// fresh from statistics-service on load/refresh, never from a local cache,
/// and shows a dedicated full-page offline state instead of stale data when
/// there's no connectivity.
final class DashboardCubit extends Cubit<DashboardState> with DashboardEmitter {
  DashboardCubit({
    required this.statisticsReader,
    required this.apiaryReader,
    required this.hiveReader,
    required this.inspectionReader,
    required this.connectivity,
  }) : super(const DashboardLoading()) {
    _connectivitySubscription = connectivity.status.listen(
      (isOnline) => emitOfflineIfConnectionLost(isOnline: isOnline),
    );
  }

  final IStatisticsReader statisticsReader;
  final IApiaryReader apiaryReader;
  final IHiveReader hiveReader;
  final IInspectionReader inspectionReader;
  final IConnectivityService connectivity;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Initial load — replaces the body with a full-screen spinner.
  Future<void> loadDashboard() => emitLoad(statisticsReader, connectivity);

  /// Pull-to-refresh — keeps the current sections visible while refetching.
  Future<void> refresh() => emitRefresh(statisticsReader, connectivity);

  /// Used by the full-page offline state's Retry button — always re-checks
  /// connectivity and, if online, fetches fresh (never cached) data.
  Future<void> retry() => emitLoad(statisticsReader, connectivity);

  Future<void> retryOverview() => emitRetryOverview(statisticsReader);

  Future<void> retryApiaryStats() => emitRetryApiaryStats(statisticsReader);

  Future<void> retryInspectionStats() =>
      emitRetryInspectionStats(statisticsReader);

  Future<void> retryRecentActivity() =>
      emitRetryRecentActivity(statisticsReader);

  /// Fetch-then-navigate passthroughs for the Dashboard's tap targets — the
  /// stats endpoints only return id+name for these, not the full entity the
  /// existing `*DetailsRoute`s need, so the tapped tile fetches it first.
  /// These don't touch [state]; the caller widget owns its own pending/error
  /// UI for the tap.
  Future<Either<Failure, Apiary>> fetchApiary(String id) =>
      apiaryReader.getApiary(id);

  Future<Either<Failure, Hive>> fetchHive(String id) => hiveReader.getHive(id);

  Future<Either<Failure, Inspection>> fetchInspection({
    required String hiveId,
    required String id,
  }) => inspectionReader.getInspection(hiveId: hiveId, id: id);

  @override
  Future<void> close() {
    unawaited(_connectivitySubscription?.cancel());
    return super.close();
  }
}
