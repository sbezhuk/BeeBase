import 'package:beebase/domain/entity/inspection.dart';

abstract interface class IInspectionLocalDataSource {
  /// Fetches active inspections (excluding [SyncStatus.pendingDelete])
  /// belonging to [hiveId] — matched against either the local or server
  /// hive id, so it works whether the parent has synced yet or not.
  Future<List<Inspection>> getActiveInspectionsForHive({
    required String hiveId,
    required int page,
    required int limit,
  });

  /// Finds an inspection by its [localId] or [serverId].
  Future<Inspection?> getInspectionById(String id);

  /// Saves inspections fetched from server. Preserves any local pending
  /// modifications or pending creations.
  Future<void> saveServerInspections(List<Inspection> inspections);

  /// Inserts a newly created inspection into SQLite.
  Future<Inspection> insertInspection(Inspection inspection);

  /// Updates an existing inspection in SQLite.
  Future<Inspection> updateInspection(Inspection inspection);

  /// Permanently removes the record from SQLite.
  Future<void> deleteInspectionPermanently(String localId);

  /// Marks an existing record as [SyncStatus.pendingDelete].
  Future<void> markPendingDelete(String id);

  /// Returns all inspections that need synchronization (pendingCreate,
  /// pendingUpdate, pendingDelete).
  Future<List<Inspection>> getPendingSyncInspections();

  /// Same as [getPendingSyncInspections], scoped to inspections belonging
  /// to [hiveId] (local or server id) — used to overlay local pending edits
  /// onto a freshly-fetched server page for that hive.
  Future<List<Inspection>> getPendingSyncInspectionsForHive(String hiveId);

  /// Updates an inspection's sync status and backend serverId atomically.
  Future<void> markSynced({required String localId, required String serverId});

  /// Called once the owning hive's [Inspection.hiveLocalId] resolves to a
  /// real backend id — updates every inspection still tracking that local
  /// hive so they can be synchronized with the correct `hive_id`.
  Future<void> resolveHiveServerId({
    required String hiveLocalId,
    required String hiveServerId,
  });

  /// Every inspection (regardless of sync status) belonging to [hiveId] —
  /// matched against either the local or server hive id. Used to enumerate
  /// descendants before a cascade delete.
  Future<List<Inspection>> getInspectionsByHiveId(String hiveId);

  /// Permanently removes every inspection belonging to [hiveId] (local or
  /// server id), regardless of sync status. Used to mirror the backend's
  /// cascade delete locally when the owning hive is deleted — see
  /// `HiveRepositoryImpl.deleteHive`.
  Future<void> deleteInspectionsByHiveId(String hiveId);
}
