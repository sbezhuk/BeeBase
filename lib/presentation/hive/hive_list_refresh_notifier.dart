import 'package:beebase/core/offline/sync_activity.dart';
import 'package:beebase/core/offline/sync_coalesced_signal.dart';

/// Broadcasts a signal whenever a hive is created, edited, or deleted.
///
/// [HiveFormRoute] and [HiveDetailsRoute] are pushed on the root router
/// (they're siblings of [MainRoute], not nested under any tab), so
/// AutoRoute's `didPopNext` never reaches [HiveListPage] — that callback
/// only fires for a route revealed within the same navigator that popped.
/// [HiveListCubit] subscribes to [onChanged] instead to refresh itself
/// regardless of which navigator the change came from.
///
/// Delegates to [SyncCoalescedSignal] so that a sync batch touching several
/// hives only triggers one refresh once the whole batch finishes, instead
/// of one per synced operation — see that class's doc.
final class HiveListRefreshNotifier {
  HiveListRefreshNotifier({
    SyncActivity syncActivity = const NeverSyncingActivity(),
  }) : _signal = SyncCoalescedSignal(syncActivity);

  final SyncCoalescedSignal _signal;

  Stream<void> get onChanged => _signal.onChanged;

  void notify() => _signal.notify();

  void dispose() => _signal.dispose();
}
