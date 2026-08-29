import 'package:beebase/core/offline/offline_operation.dart';

/// Generic persistence boundary for pending mutations. Entirely
/// entity-agnostic — it stores whatever [OfflineOperation]s it's given and
/// has no idea what an "Apiary" is.
abstract interface class OperationQueue {
  Future<List<OfflineOperation>> all();

  /// The current row for [id], or `null` if it no longer exists. Used to
  /// read back the latest state of an operation after some other write may
  /// have touched it concurrently — see `SyncEngineImpl._process`.
  Future<OfflineOperation?> find(String id);

  Future<void> enqueue(OfflineOperation operation);

  Future<void> update(OfflineOperation operation);

  Future<void> remove(String operationId);

  /// Fires after every [enqueue]/[update]/[remove] — the generic signal
  /// `SyncEngine` (and, through it, any UI showing "offline data pending")
  /// listens to, without knowing which entity type changed.
  Stream<void> get changes;
}
