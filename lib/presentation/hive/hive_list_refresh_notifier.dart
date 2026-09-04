import 'dart:async';

/// Broadcasts a signal whenever a hive is created, edited, or deleted.
///
/// [HiveFormRoute] and [HiveDetailsRoute] are pushed on the root router
/// (they're siblings of [MainRoute], not nested under any tab), so
/// AutoRoute's `didPopNext` never reaches [HiveListPage] — that callback
/// only fires for a route revealed within the same navigator that popped.
/// [HiveListCubit] subscribes to [onChanged] instead to refresh itself
/// regardless of which navigator the change came from.
final class HiveListRefreshNotifier {
  HiveListRefreshNotifier();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get onChanged => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => unawaited(_controller.close());
}
