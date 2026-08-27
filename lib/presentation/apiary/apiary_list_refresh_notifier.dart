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
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onChanged => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}
