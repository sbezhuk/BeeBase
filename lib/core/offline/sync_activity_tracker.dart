import 'package:beebase/core/offline/sync_activity.dart';
import 'package:flutter/foundation.dart';

/// Owns the single "is a sync batch currently running" flag. Only
/// `SyncEngineImpl` ever calls [start]/[finish] — everything else (the
/// per-entity refresh notifiers, any UI wanting one continuous loader for
/// the whole sync) only ever reads [isSyncing] through the narrower
/// [SyncActivity] view. See [SyncActivity]'s doc for why this is a separate
/// leaf class rather than every reader depending on `SyncEngine` directly.
final class SyncActivityTracker implements SyncActivity {
  final ValueNotifier<bool> _isSyncing = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get isSyncing => _isSyncing;

  void start() => _isSyncing.value = true;

  void finish() => _isSyncing.value = false;
}
