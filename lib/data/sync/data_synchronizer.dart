import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';

final class DataSyncResult {
  const DataSyncResult({required this.apiaries, required this.hives});

  final ApiarySyncResult apiaries;
  final HiveSyncResult hives;

  int get syncedCount => apiaries.syncedCount + hives.syncedCount;
  int get failedCount => apiaries.failedCount + hives.failedCount;
  int get totalPending => apiaries.totalPending + hives.totalPending;
  List<String> get errors => [...apiaries.errors, ...hives.errors];

  bool get isSuccess => apiaries.isSuccess && hives.isSuccess;
}

abstract interface class IDataSynchronizer {
  /// Runs the full sync pass in the one order the backend allows: every
  /// pending apiary first, then every pending hive. This is the single
  /// entry point the UI (see `ProfileSyncSection`) should call — the
  /// `Apiary -> Hive` dependency is enforced here, in the data layer, not
  /// left for a caller to get right.
  Future<DataSyncResult> syncAll();
}

final class DataSynchronizer implements IDataSynchronizer {
  DataSynchronizer({
    required this.apiarySynchronizer,
    required this.hiveSynchronizer,
  });

  final IApiarySynchronizer apiarySynchronizer;
  final IHiveSynchronizer hiveSynchronizer;

  @override
  Future<DataSyncResult> syncAll() async {
    final apiaryResult = await apiarySynchronizer.syncApiaries();
    final hiveResult = await hiveSynchronizer.syncHives();
    return DataSyncResult(apiaries: apiaryResult, hives: hiveResult);
  }
}
