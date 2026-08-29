import 'dart:convert';

import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/offline_operation_row_mapper.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/storage/app_database.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteOfflineMutationStore implements OfflineMutationStore {
  SqliteOfflineMutationStore({required this._database, required this._changeNotifier});

  final AppDatabase _database;
  final OfflineOperationsChangeNotifier _changeNotifier;

  @override
  Future<void> saveWithPendingOperation<T>({
    required String cacheKey,
    required T Function(T? current) mutate,
    required Object? Function(T value) toJson,
    required T Function(Object? json) fromJson,
    required OfflineOperation operation,
  }) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      final rows = await txn.query('key_value_cache', where: 'cache_key = ?', whereArgs: [cacheKey], limit: 1);
      final current = rows.isEmpty ? null : fromJson(jsonDecode(rows.single['value']! as String));
      final next = mutate(current);
      await txn.insert('key_value_cache', {
        'cache_key': cacheKey,
        'value': jsonEncode(toJson(next)),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert(
        'offline_operations',
        OfflineOperationRowMapper.toRow(operation),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _changeNotifier.notify();
  }
}
