import 'dart:async';

/// Broadcasts a signal whenever an inspection is created, edited, or
/// deleted.
///
/// [InspectionFormRoute] and [InspectionDetailsRoute] are pushed on the root
/// router (they're siblings of [MainRoute], not nested under any tab), so
/// AutoRoute's `didPopNext` never reaches [InspectionListPage] — that
/// callback only fires for a route revealed within the same navigator that
/// popped. [InspectionListCubit] subscribes to [onChanged] instead to
/// refresh itself regardless of which navigator the change came from.
final class InspectionListRefreshNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onChanged => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}
