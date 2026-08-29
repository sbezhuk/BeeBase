import 'dart:async';

/// Single broadcast signal shared by every writer of the `offline_operations`
/// table (`SqliteOperationQueue` and `SqliteOfflineMutationStore` both write
/// to it, the latter inside its own transaction) so `SyncEngine` sees a
/// change regardless of which one made it.
final class OfflineOperationsChangeNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() => _controller.add(null);
}
