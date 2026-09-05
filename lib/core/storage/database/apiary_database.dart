import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class ApiaryDatabase {
  ApiaryDatabase({this._database, String? databaseName}) : _databaseName = databaseName ?? dbName;

  Database? _database;
  final String _databaseName;
  static const int _version = 4;
  static const String dbName = 'beebase_apiary.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _init();
    return _database!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    return openDatabase(path, version: _version, onCreate: _onCreate, onUpgrade: _onUpgrade);
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

    await db.execute('CREATE INDEX idx_apiaries_sync_status ON apiaries(sync_status)');
    await db.execute('CREATE INDEX idx_apiaries_server_id ON apiaries(server_id)');

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

    await db.execute('CREATE INDEX idx_local_media_owner ON local_media(owner_type, owner_id)');

    await _createHivesTable(db);
    await _createInspectionsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createHivesTable(db);
    }
    if (oldVersion < 3) {
      // Includes the `images` column already (see `_createInspectionsTable`),
      // so the oldVersion == 3 branch below — which adds that column to a
      // table that already existed without it — must not also run here.
      await _createInspectionsTable(db);
    } else if (oldVersion == 3) {
      await db.execute("ALTER TABLE inspections ADD COLUMN images TEXT NOT NULL DEFAULT '[]'");
    }
  }

  /// A hive belongs to an apiary (see `Hive.apiaryLocalId`/`apiaryServerId`)
  /// which, while that apiary is still `pendingCreate`, may not have a
  /// server id yet — both columns are kept (rather than a single nullable
  /// `apiary_id`) so `HiveSynchronizer` can resolve the local->server id
  /// once the parent apiary syncs without losing track of which local
  /// apiary a still-unsynced hive belongs to.
  Future<void> _createHivesTable(Database db) async {
    await db.execute('''
      CREATE TABLE hives (
        local_id TEXT PRIMARY KEY,
        server_id TEXT UNIQUE,
        apiary_local_id TEXT,
        apiary_server_id TEXT,
        name TEXT NOT NULL,
        notes TEXT,
        images TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_hives_sync_status ON hives(sync_status)');
    await db.execute('CREATE INDEX idx_hives_server_id ON hives(server_id)');
    await db.execute('CREATE INDEX idx_hives_apiary_local_id ON hives(apiary_local_id)');
    await db.execute('CREATE INDEX idx_hives_apiary_server_id ON hives(apiary_server_id)');
  }

  /// An inspection belongs to a hive (see `Inspection.hiveLocalId`/
  /// `hiveServerId`) which, while that hive is still `pendingCreate`, may
  /// not have a server id yet — both columns are kept for the same reason
  /// `hives.apiary_local_id`/`apiary_server_id` are (see [_createHivesTable]):
  /// so `InspectionSynchronizer` can resolve the local->server id once the
  /// parent hive syncs without losing track of which local hive a
  /// still-unsynced inspection belongs to. `images` mirrors
  /// `apiaries.images`/`hives.images` — a JSON-encoded list of media ids,
  /// inspection-service's own source of truth once synced.
  Future<void> _createInspectionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE inspections (
        local_id TEXT PRIMARY KEY,
        server_id TEXT UNIQUE,
        hive_local_id TEXT,
        hive_server_id TEXT,
        inspected_at TEXT NOT NULL,
        type TEXT NOT NULL,
        notes TEXT NOT NULL,
        images TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_inspections_sync_status ON inspections(sync_status)');
    await db.execute('CREATE INDEX idx_inspections_server_id ON inspections(server_id)');
    await db.execute('CREATE INDEX idx_inspections_hive_local_id ON inspections(hive_local_id)');
    await db.execute('CREATE INDEX idx_inspections_hive_server_id ON inspections(hive_server_id)');
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

  /// Closes the database and deletes its underlying file, wiping every
  /// apiary, hive, inspection and local-media row it holds in one go —
  /// used on account deletion, where none of that offline data (synced or
  /// still-pending) may survive. The next [database] access transparently
  /// recreates an empty file via [_onCreate].
  Future<void> deleteDatabaseFile() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
  }
}
