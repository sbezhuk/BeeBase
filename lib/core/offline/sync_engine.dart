/// Centralized synchronization mechanism — the only thing in the app that
/// knows how/when pending operations get processed. Entity-agnostic:
/// dispatches to whatever `OperationHandler` is registered for each
/// operation's entity type via `OperationRegistry`.
abstract interface class SyncEngine {
  /// Runs an initial sync attempt and subscribes to connectivity changes,
  /// triggering [syncNow] whenever the device comes back online.
  void start();

  /// Processes every pending operation once. No-op if offline.
  Future<void> syncNow();
}
