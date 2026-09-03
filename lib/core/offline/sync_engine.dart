import 'package:flutter/foundation.dart';

/// Centralized synchronization mechanism — the only thing in the app that
/// knows how pending operations get processed. Entity-agnostic: dispatches
/// to whatever `OperationHandler` is registered for each operation's entity
/// type via `OperationRegistry`. Synchronization itself only ever runs via
/// [syncNow], triggered exclusively by explicit user action (the "Sync now"
/// banner action, the Profile screen's sync row) — connectivity restoration,
/// app start/resume, opening a screen, and a locally queued change all only
/// ever update [syncAvailable]/[hasPendingOperations]; none of them call
/// [syncNow] themselves. This is a deliberate product decision, not an
/// oversight: the user must always be the one who decides when a sync
/// actually starts.
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

  /// True for the entire duration of one [syncNow] call — flips to `true`
  /// the moment a sync actually starts processing operations and back to
  /// `false` only once every operation (including every in-pass retry) has
  /// been attempted, never in between. This is the single authoritative
  /// "a sync is running" signal: any UI wanting one continuous loader for
  /// the whole synchronization process (rather than one that flickers per
  /// operation) should key off this and nothing else.
  ValueListenable<bool> get isSyncing;

  /// Starts watching connectivity/queue changes to keep [syncAvailable] and
  /// [hasPendingOperations] current. Never itself calls [syncNow] — a
  /// reconnect or a newly queued change only ever changes whether syncing is
  /// *available*, it never starts one.
  void start();

  /// Re-derives [syncAvailable] and [hasPendingOperations] immediately (e.g.
  /// on app resume, to catch a connectivity change missed while
  /// backgrounded). Purely a re-derivation of those two flags — it never
  /// calls [syncNow] either.
  Future<void> refreshAvailability();

  /// Processes every pending/failed operation once (retrying, within this
  /// same call, anything still transiently failing — see [isSyncing]). No-op
  /// if offline or if a sync is already running. This is the *only* thing in
  /// the app that starts a sync, and it only ever runs in direct response to
  /// an explicit user action — never automatically.
  Future<void> syncNow();
}
