import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class ApiaryDatabase {
  ApiaryDatabase({Database? database, String? databaseName})
      : _database = database,
        _databaseName = databaseName ?? dbName;

  Database? _database;
  final String _databaseName;
  static const int _version = 1;
  static const String dbName = 'beebase_apiary.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _init();
    return _database!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE apiaries (
        local_id TEXT PRIMARY KEY,
        server_id TEXT UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        location TEXT,
        lat REAL,
        lon REAL,
        images TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_apiaries_sync_status ON apiaries(sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_apiaries_server_id ON apiaries(server_id)',
    );

    await db.execute('''
      CREATE TABLE local_media (
        local_id TEXT PRIMARY KEY,
        server_id TEXT,
        owner_type TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        local_file_path TEXT NOT NULL,
        original_filename TEXT NOT NULL,
        content_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_local_media_owner ON local_media(owner_type, owner_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations for future database versions
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
