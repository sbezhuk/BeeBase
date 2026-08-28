import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';

/// [OperationQueue] backed by a single cached list. Every mutation is
/// serialized through [_lock] — two `async` methods can interleave at an
/// `await` point, and without this a concurrent enqueue/update/remove could
/// read-modify-write over each other and silently drop an operation.
final class LocalOperationQueue implements OperationQueue {
  LocalOperationQueue({required LocalDataSource<List<OfflineOperation>> storage}) : _storage = storage;

  final LocalDataSource<List<OfflineOperation>> _storage;
  Future<void> _lock = Future.value();

  @override
  Future<List<OfflineOperation>> all() async => (await _storage.read()) ?? const [];

  @override
  Future<void> enqueue(OfflineOperation operation) {
    return _synchronized(() async {
      final operations = await all();
      await _storage.write([...operations, operation]);
    });
  }

  @override
  Future<void> update(OfflineOperation operation) {
    return _synchronized(() async {
      final operations = await all();
      await _storage.write([for (final existing in operations) existing.id == operation.id ? operation : existing]);
    });
  }

  @override
  Future<void> remove(String operationId) {
    return _synchronized(() async {
      final operations = await all();
      await _storage.write([
        for (final existing in operations)
          if (existing.id != operationId) existing,
      ]);
    });
  }

  Future<void> _synchronized(Future<void> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.catchError((_) {});
    return result;
  }
}
