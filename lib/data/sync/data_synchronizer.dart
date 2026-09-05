import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';
import 'package:beebase/data/sync/inspection_synchronizer.dart';

final class DataSyncResult {
  const DataSyncResult({
    required this.apiaries,
    required this.hives,
    required this.inspections,
  });

  final ApiarySyncResult apiaries;
  final HiveSyncResult hives;
  final InspectionSyncResult inspections;

  int get syncedCount =>
      apiaries.syncedCount + hives.syncedCount + inspections.syncedCount;
  int get failedCount =>
      apiaries.failedCount + hives.failedCount + inspections.failedCount;
  int get totalPending =>
      apiaries.totalPending + hives.totalPending + inspections.totalPending;
  List<String> get errors => [
    ...apiaries.errors,
    ...hives.errors,
    ...inspections.errors,
  ];

  bool get isSuccess =>
      apiaries.isSuccess && hives.isSuccess && inspections.isSuccess;
}

abstract interface class IDataSynchronizer {
  /// Runs the full sync pass in the one order the backend allows: every
  /// pending apiary first, then every pending hive, then every pending
  /// inspection. This is the single entry point the UI (see
  /// `ProfileSyncSection`) should call — the `Apiary -> Hive -> Inspection`
  /// dependency is enforced here, in the data layer, not left for a caller
  /// to get right.
  Future<DataSyncResult> syncAll();
}

final class DataSynchronizer implements IDataSynchronizer {
  DataSynchronizer({
    required this.apiarySynchronizer,
    required this.hiveSynchronizer,
    required this.inspectionSynchronizer,
  });

  final IApiarySynchronizer apiarySynchronizer;
  final IHiveSynchronizer hiveSynchronizer;
  final IInspectionSynchronizer inspectionSynchronizer;

  @override
  Future<DataSyncResult> syncAll() async {
    final apiaryResult = await apiarySynchronizer.syncApiaries();
    final hiveResult = await hiveSynchronizer.syncHives();
    final inspectionResult = await inspectionSynchronizer.syncInspections();
    return DataSyncResult(
      apiaries: apiaryResult,
      hives: hiveResult,
      inspections: inspectionResult,
    );
  }
}
