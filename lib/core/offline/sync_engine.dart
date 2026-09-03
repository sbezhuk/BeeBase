import 'package:flutter/foundation.dart';

/// Centralized synchronization mechanism — the only thing in the app that
/// knows how pending operations get processed. Entity-agnostic: dispatches
/// to whatever `OperationHandler` is registered for each operation's entity
/// type via `OperationRegistry`. All processing still funnels through
/// [syncNow] — but that call is no longer only user-initiated: [start] (and
/// [refreshAvailability]) detect an offline→online transition and invoke
/// [syncNow] automatically, so a reconnect drains the queue without the user
/// having to tap "Sync now". The manual entry point remains for the banner's
/// retry action and stays safe to call concurrently — [syncNow] is a no-op
/// while a sync is already running or the device is offline.
abstract interface class SyncEngine {
  /// True iff the device is online AND at least one operation is still
  /// awaiting synchronization — the generic signal any offline banner
  /// listens to, regardless of entity type. A [ValueListenable] (not a
  /// stream) so listeners are only notified on an actual change, which is
  /// what keeps a banner driven by this from "spamming" on every rebuild.
  ValueListenable<bool> get syncAvailable;

  /// True iff at least one operation is still awaiting synchronization,
  /// regardless of connectivity — unlike [syncAvailable], this doesn't
  /// require the device to currently be online. For a surface that wants to
  /// say "there's data waiting to sync" even while offline (e.g. a Profile
  /// screen's sync status), where [syncAvailable] would wrongly read as
  /// "nothing to sync" just because there's no connection right now.
  ValueListenable<bool> get hasPendingOperations;

  /// Starts watching connectivity/queue changes to keep [syncAvailable] and
  /// [hasPendingOperations] current. Also arms automatic synchronization:
  /// every connectivity event and every call this triggers to
  /// [refreshAvailability] checks for an offline→online transition and, if
  /// one just happened and operations are pending, kicks off [syncNow] in
  /// the background without any user action.
  void start();

  /// Re-derives [syncAvailable] and [hasPendingOperations] immediately (e.g.
  /// on app resume, to catch a connectivity change missed while
  /// backgrounded). If this call observes the device transitioning from
  /// offline to online with operations still pending, it also starts
  /// [syncNow] automatically — the same trigger [start]'s connectivity
  /// listener uses.
  Future<void> refreshAvailability();

  /// Processes every pending/failed operation once. No-op if offline or if a
  /// sync is already running. Invoked automatically on reconnect (see
  /// [start]/[refreshAvailability]) and also safe to call directly for a
  /// manual retry (e.g. the sync banner's "Sync now" action).
  Future<void> syncNow();
}
