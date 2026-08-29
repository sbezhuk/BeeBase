import 'dart:io';

import 'package:beebase/core/storage/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _counter = 0;

/// Opens a fresh, real SQLite database for a test — no platform channel
/// needed, per `sqflite_common_ffi`'s standard test setup. Uses a unique
/// temp-file path per call rather than `inMemoryDatabasePath`: the ffi
/// factory caches open connections by path, so two calls with that fixed
/// constant return the *same* underlying database and tests would leak
/// state into one another.
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final path = p.join(Directory.systemTemp.path, 'beebase_test_${DateTime.now().microsecondsSinceEpoch}_${_counter++}.db');
  final database = AppDatabase(factory: databaseFactoryFfi, pathOverride: path);
  await database.open();
  return database;
}
