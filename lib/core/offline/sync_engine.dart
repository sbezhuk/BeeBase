import 'package:flutter/foundation.dart';

/// Centralized synchronization mechanism — the only thing in the app that
/// knows how pending operations get processed. Entity-agnostic: dispatches
/// to whatever `OperationHandler` is registered for each operation's entity
/// type via `OperationRegistry`. Synchronization itself only ever runs via
/// [syncNow], triggered by an explicit user action — connectivity
/// restoration alone only updates [syncAvailable], it never auto-syncs.
abstract interface class SyncEngine {
  /// True iff the device is online AND at least one operation is still
  /// awaiting synchronization — the generic signal any offline banner
  /// listens to, regardless of entity type. A [ValueListenable] (not a
  /// stream) so listeners are only notified on an actual change, which is
  /// what keeps a banner driven by this from "spamming" on every rebuild.
  ValueListenable<bool> get syncAvailable;

  /// Starts watching connectivity/queue changes to keep [syncAvailable]
  /// current. Does not sync anything by itself.
  void start();

  /// Re-derives [syncAvailable] immediately (e.g. on app resume) without
  /// any network side effect beyond a connectivity check.
  Future<void> refreshAvailability();

  /// Processes every pending/failed operation once. No-op if offline. Only
  /// ever called in response to explicit user action (e.g. "Sync now").
  Future<void> syncNow();
}
