import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/sync_status.dart';

abstract interface class IApiaryLocalDataSource {
  /// Fetches active apiaries (excluding [SyncStatus.pendingDelete]) with pagination.
  Future<List<Apiary>> getActiveApiaries({required int page, required int limit});

  /// Finds an apiary by its [localId] or [serverId].
  Future<Apiary?> getApiaryById(String id);

  /// Saves apiaries fetched from server. Preserves any local pending modifications
  /// or pending creations.
  Future<void> saveServerApiaries(List<Apiary> apiaries);

  /// Inserts a newly created apiary into SQLite.
  Future<Apiary> insertApiary(Apiary apiary);

  /// Updates an existing apiary in SQLite.
  Future<Apiary> updateApiary(Apiary apiary);

  /// Permanently removes the record from SQLite.
  Future<void> deleteApiaryPermanently(String localId);

  /// Marks an existing record as [SyncStatus.pendingDelete].
  Future<void> markPendingDelete(String id);

  /// Returns all apiaries that need synchronization (pendingCreate, pendingUpdate, pendingDelete).
  Future<List<Apiary>> getPendingSyncApiaries();

  /// Updates an apiary's sync status and backend serverId atomically.
  Future<void> markSynced({
    required String localId,
    required String serverId,
    List<String>? images,
  });

  /// Media persistence methods
  Future<void> saveLocalMedia(LocalMedia media);
  Future<List<LocalMedia>> getLocalMediaForOwner(String ownerId);
  Future<LocalMedia?> getLocalMediaById(String localId);
  Future<void> updateLocalMediaStatus(String localId, SyncStatus status, {String? serverId});
  Future<void> deleteLocalMedia(String localId);

  /// Returns all [LocalMedia] rows that still need to be uploaded to the server
  /// (i.e. [SyncStatus.pendingCreate]). Used by the synchronizer's orphan-media
  /// sweep to catch photos attached to apiaries that are otherwise `synced`.
  Future<List<LocalMedia>> getPendingMedia();
}
