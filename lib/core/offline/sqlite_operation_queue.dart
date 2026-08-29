import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/offline_operation_row_mapper.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/storage/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [OperationQueue] backed by the `offline_operations` table — each
/// operation is its own row, so `enqueue`/`update`/`remove` are single,
/// independently-atomic SQL statements. Unlike a JSON-blob-list cache,
/// there's no read-the-whole-list-then-write-it-back step here, so there's
/// no lost-update race to guard with an application-level lock.
final class SqliteOperationQueue implements OperationQueue {
  SqliteOperationQueue({required this._database, required this._changeNotifier});

  static const _table = 'offline_operations';

  final AppDatabase _database;
  final OfflineOperationsChangeNotifier _changeNotifier;

  @override
  Stream<void> get changes => _changeNotifier.changes;

  @override
  Future<List<OfflineOperation>> all() async {
    final db = await _database.open();
    final rows = await db.query(_table, orderBy: 'created_at ASC');
    return rows.map(OfflineOperationRowMapper.fromRow).toList();
  }

  @override
  Future<void> enqueue(OfflineOperation operation) async {
    final db = await _database.open();
    await db.insert(_table, OfflineOperationRowMapper.toRow(operation), conflictAlgorithm: ConflictAlgorithm.replace);
    _changeNotifier.notify();
  }

  @override
  Future<void> update(OfflineOperation operation) async {
    final db = await _database.open();
    await db.update(_table, OfflineOperationRowMapper.toRow(operation), where: 'id = ?', whereArgs: [operation.id]);
    _changeNotifier.notify();
  }

  @override
  Future<void> remove(String operationId) async {
    final db = await _database.open();
    await db.delete(_table, where: 'id = ?', whereArgs: [operationId]);
    _changeNotifier.notify();
  }
}
