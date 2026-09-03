import 'package:flutter/foundation.dart';

/// Read-only view of whether a sync batch is currently running. Exists as
/// its own narrow interface — rather than every consumer depending on
/// `SyncActivityTracker` (or `SyncEngine`) directly — specifically so the
/// per-entity refresh notifiers (`ApiaryListRefreshNotifier`,
/// `HiveListRefreshNotifier`, `InspectionListRefreshNotifier`) can depend on
/// it without a dependency cycle: those notifiers are themselves
/// dependencies of the operation handlers `SyncEngineImpl` is built from
/// (via `OperationRegistry`), so a notifier depending on `SyncEngine` itself
/// would ask `get_it` to resolve `SyncEngine` while it is still in the
/// middle of being constructed. `SyncActivityTracker` has no dependencies of
/// its own, so both `SyncEngineImpl` (which starts/finishes it) and the
/// notifiers (which only ever read it) can depend on it without that cycle.
abstract interface class SyncActivity {
  ValueListenable<bool> get isSyncing;
}

/// Null-object default for a [SyncActivity] collaborator: "never syncing,"
/// i.e. behave as if there were no sync-batch coalescing at all — every
/// signal forwards immediately. Real production wiring always passes the
/// actual [SyncActivityTracker] singleton through DI; this exists purely so
/// a call site with no interest in sync-batch coalescing (mostly tests for
/// the ~15 unrelated cubits that happen to hold one of the refresh
/// notifiers built on this) doesn't have to thread a fake through for no
/// reason.
final class NeverSyncingActivity implements SyncActivity {
  const NeverSyncingActivity();

  @override
  ValueListenable<bool> get isSyncing => const _AlwaysFalse();
}

final class _AlwaysFalse implements ValueListenable<bool> {
  const _AlwaysFalse();

  @override
  bool get value => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
