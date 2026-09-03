import 'dart:async';

import 'package:beebase/core/offline/sync_activity.dart';

/// Shared broadcast-signal implementation behind the per-entity refresh
/// notifiers (`ApiaryListRefreshNotifier`, `HiveListRefreshNotifier`,
/// `InspectionListRefreshNotifier`). A live, one-off change (an online
/// create/update/delete made outside of any sync batch) still notifies
/// immediately, exactly as before.
///
/// While [SyncActivity.isSyncing] is true, individual [notify] calls are
/// coalesced instead of forwarded immediately. A sync batch that touches
/// several entities (an apiary, its photo, a hive, its photo, ...) used to
/// call the underlying handler's `refreshNotifier.notify()` once per
/// operation — and since every subscribing cubit (`ApiaryListCubit`,
/// `HiveListCubit`, ...) reacts to each one by refreshing (and therefore
/// showing its own loading state) immediately, a multi-entity sync made a
/// visible screen's loader flicker on and off once per synced operation
/// instead of showing one continuous loading state for the whole process.
/// Buffering here and emitting exactly one signal once the batch finishes
/// (`isSyncing` flips back to `false`) fixes that at the source, without
/// the ~6 call sites that already listen to `onChanged` needing to know
/// anything changed.
final class SyncCoalescedSignal {
  SyncCoalescedSignal(this._syncActivity) {
    _syncActivity.isSyncing.addListener(_onSyncActivityChanged);
  }

  final SyncActivity _syncActivity;
  final StreamController<void> _controller = StreamController<void>.broadcast();
  bool _pendingWhileSyncing = false;

  Stream<void> get onChanged => _controller.stream;

  void notify() {
    if (_syncActivity.isSyncing.value) {
      _pendingWhileSyncing = true;
      return;
    }
    _controller.add(null);
  }

  void _onSyncActivityChanged() {
    if (!_syncActivity.isSyncing.value && _pendingWhileSyncing) {
      _pendingWhileSyncing = false;
      _controller.add(null);
    }
  }

  void dispose() {
    _syncActivity.isSyncing.removeListener(_onSyncActivityChanged);
    _controller.close();
  }
}
