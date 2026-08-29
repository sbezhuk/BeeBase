import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// The app's single SQLite database — the persistent foundation for all
/// offline state (cached entities and pending sync operations), generic
/// across every entity type rather than one table per feature. Opened once
/// in `initDi()` before anything that depends on it is registered; nothing
/// outside `core/storage`/the SQLite-backed data sources should touch
/// [database] or write raw SQL directly.
final class AppDatabase {
  /// [_pathOverride] bypasses `path_provider` entirely — tests pass
  /// `inMemoryDatabasePath` (from `sqflite_common_ffi`) so no platform
  /// channel is needed; production leaves it null and gets the real
  /// app-support-directory path.
  AppDatabase({DatabaseFactory? factory, this._pathOverride}) : _factory = factory ?? databaseFactory;

  static const _fileName = 'beebase.db';
  static const _version = 2;

  final DatabaseFactory _factory;
  final String? _pathOverride;
  Database? _database;

  Future<Database> open() async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final path = _pathOverride ?? p.join((await getApplicationSupportDirectory()).path, _fileName);
    final database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: _version, onCreate: _onCreate, onUpgrade: _onUpgrade),
    );
    _database = database;
    return database;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE key_value_cache (
        cache_key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE offline_operations (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL,
        last_error TEXT,
        local_entity_id TEXT,
        depends_on_operation_id TEXT,
        version INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE offline_operations ADD COLUMN version INTEGER NOT NULL DEFAULT 0');
    }
  }
}
