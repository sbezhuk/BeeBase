import 'dart:async';

/// Broadcasts a signal whenever an apiary is created, edited, or deleted.
///
/// [ApiaryFormRoute] and [ApiaryDetailsRoute] are pushed on the root router
/// (they're siblings of [MainRoute], not nested under its Apiaries tab), so
/// AutoRoute's `didPopNext` never reaches [ApiaryListPage] — that callback
/// only fires for a route revealed within the same navigator that popped.
/// [ApiaryListCubit] subscribes to [onChanged] instead to refresh itself
/// regardless of which navigator the change came from.
final class ApiaryListRefreshNotifier {
  ApiaryListRefreshNotifier();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get onChanged => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => unawaited(_controller.close());
}
