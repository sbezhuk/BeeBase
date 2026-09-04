import 'package:beebase/domain/entity/hive.dart';

abstract interface class IHiveLocalDataSource {
  /// Fetches active hives (excluding [SyncStatus.pendingDelete]) belonging
  /// to [apiaryId] — matched against either the local or server apiary id,
  /// so it works whether the parent has synced yet or not.
  Future<List<Hive>> getActiveHivesForApiary({
    required String apiaryId,
    required int page,
    required int limit,
  });

  /// Every active hive the caller owns, across every apiary — used to
  /// compute per-apiary counts while offline (see `HiveRepositoryImpl.getHiveCounts`).
  Future<List<Hive>> getAllActiveHives();

  /// Finds a hive by its [localId] or [serverId].
  Future<Hive?> getHiveById(String id);

  /// Saves hives fetched from server. Preserves any local pending
  /// modifications or pending creations.
  Future<void> saveServerHives(List<Hive> hives);

  /// Inserts a newly created hive into SQLite.
  Future<Hive> insertHive(Hive hive);

  /// Updates an existing hive in SQLite.
  Future<Hive> updateHive(Hive hive);

  /// Permanently removes the record from SQLite.
  Future<void> deleteHivePermanently(String localId);

  /// Marks an existing record as [SyncStatus.pendingDelete].
  Future<void> markPendingDelete(String id);

  /// Returns all hives that need synchronization (pendingCreate, pendingUpdate, pendingDelete).
  Future<List<Hive>> getPendingSyncHives();

  /// Same as [getPendingSyncHives], scoped to hives belonging to [apiaryId]
  /// (local or server id) — used to overlay local pending edits onto a
  /// freshly-fetched server page for that apiary.
  Future<List<Hive>> getPendingSyncHivesForApiary(String apiaryId);

  /// Updates a hive's sync status and backend serverId atomically.
  Future<void> markSynced({
    required String localId,
    required String serverId,
    List<String>? images,
  });

  /// Called once the owning apiary's [apiaryLocalId] resolves to a real
  /// backend id — updates every hive still tracking that local apiary so
  /// they can be synchronized with the correct `apiary_id`.
  Future<void> resolveApiaryServerId({
    required String apiaryLocalId,
    required String apiaryServerId,
  });

  /// Permanently removes every hive belonging to the offline-only apiary
  /// [apiaryLocalId]. Safe to call unconditionally when that apiary is
  /// deleted before ever syncing: since a hive can only sync after its
  /// parent apiary does, none of these hives can have reached the backend
  /// either.
  Future<void> deleteHivesByApiaryLocalId(String apiaryLocalId);
}
