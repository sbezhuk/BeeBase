import 'package:beebase/core/offline/local_operation_queue.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real (non-mock) in-memory [LocalDataSource] whose [write] can be
/// delayed, so tests can widen the race window between two concurrent
/// queue mutations and prove [LocalOperationQueue]'s lock prevents a lost
/// update — a mock's `when(...).thenAnswer` can't reproduce a genuine
/// read-modify-write race the way a real, stateful store can.
class _DelayedInMemoryStorage implements LocalDataSource<List<OfflineOperation>> {
  List<OfflineOperation>? _value;
  Duration writeDelay = Duration.zero;

  @override
  Future<List<OfflineOperation>?> read() async => _value;

  @override
  Future<void> write(List<OfflineOperation> data) async {
    if (writeDelay > Duration.zero) {
      await Future<void>.delayed(writeDelay);
    }
    _value = data;
  }

  @override
  Future<void> clear() async => _value = null;
}

OfflineOperation _operation(String id, {String? localEntityId, OperationStatus status = OperationStatus.pending}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'Test'},
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
  );
}

void main() {
  late _DelayedInMemoryStorage storage;
  late LocalOperationQueue queue;

  setUp(() {
    storage = _DelayedInMemoryStorage();
    queue = LocalOperationQueue(storage: storage);
  });

  test('all() returns an empty list when nothing was ever stored', () async {
    expect(await queue.all(), isEmpty);
  });

  test('enqueue appends an operation', () async {
    await queue.enqueue(_operation('op-1'));
    await queue.enqueue(_operation('op-2'));

    final all = await queue.all();
    expect(all.map((operation) => operation.id), ['op-1', 'op-2']);
  });

  test('update replaces only the matching operation', () async {
    await queue.enqueue(_operation('op-1'));
    await queue.enqueue(_operation('op-2'));

    await queue.update(_operation('op-1', status: OperationStatus.synced));

    final all = await queue.all();
    expect(all.firstWhere((operation) => operation.id == 'op-1').status, OperationStatus.synced);
    expect(all.firstWhere((operation) => operation.id == 'op-2').status, OperationStatus.pending);
  });

  test('remove drops only the matching operation', () async {
    await queue.enqueue(_operation('op-1'));
    await queue.enqueue(_operation('op-2'));

    await queue.remove('op-1');

    final all = await queue.all();
    expect(all.map((operation) => operation.id), ['op-2']);
  });

  test('two concurrent enqueue calls do not lose an operation to a race', () async {
    storage.writeDelay = const Duration(milliseconds: 20);

    final first = queue.enqueue(_operation('op-1'));
    final second = queue.enqueue(_operation('op-2'));
    await Future.wait([first, second]);

    final all = await queue.all();
    expect(all.map((operation) => operation.id).toSet(), {'op-1', 'op-2'});
  });
}
