import 'dart:async';
import 'dart:convert';

import 'package:beebase/core/storage/app_database.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:sqflite/sqflite.dart';

/// Stores [T] as a JSON-encoded string under [key] in the shared
/// `key_value_cache` table — the SQLite-backed generalization of a simple
/// per-key blob cache, usable by any entity type without a schema change.
final class SqliteLocalDataSource<T> implements LocalDataSource<T> {
  SqliteLocalDataSource({required this._database, required this._key, required this._toJson, required this._fromJson});

  final AppDatabase _database;
  final String _key;
  final Object? Function(T data) _toJson;
  final T Function(Object? json) _fromJson;
  Future<void> _lock = Future.value();

  @override
  Future<T?> read() async {
    final db = await _database.open();
    final rows = await db.query('key_value_cache', where: 'cache_key = ?', whereArgs: [_key], limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    try {
      return _fromJson(jsonDecode(rows.single['value'] as String));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(T data) async {
    final db = await _database.open();
    await db.insert('key_value_cache', {
      'cache_key': _key,
      'value': jsonEncode(_toJson(data)),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clear() async {
    final db = await _database.open();
    await db.delete('key_value_cache', where: 'cache_key = ?', whereArgs: [_key]);
  }

  @override
  Future<void> modify(FutureOr<T> Function(T? current) update) {
    final result = _lock.then((_) async {
      final current = await read();
      final next = await update(current);
      await write(next);
    });
    _lock = result.catchError((_) {});
    return result;
  }
}
