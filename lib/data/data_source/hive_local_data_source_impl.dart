import 'dart:convert';

import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:sqflite/sqflite.dart';

final class HiveLocalDataSourceImpl implements IHiveLocalDataSource {
  HiveLocalDataSourceImpl({required ApiaryDatabase database})
    : _apiaryDatabase = database;

  final ApiaryDatabase _apiaryDatabase;

  Future<Database> get _db => _apiaryDatabase.database;

  @override
  Future<List<Hive>> getActiveHivesForApiary({
    required String apiaryId,
    required int page,
    required int limit,
  }) async {
    final db = await _db;
    final offset = (page - 1) * limit;
    final rows = await db.query(
      'hives',
      where:
          '(apiary_local_id = ? OR apiary_server_id = ?) AND sync_status != ?',
      whereArgs: [apiaryId, apiaryId, SyncStatus.pendingDelete.name],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_rowToHive).toList();
  }

  @override
  Future<List<Hive>> getAllActiveHives() async {
    final db = await _db;
    final rows = await db.query(
      'hives',
      where: 'sync_status != ?',
      whereArgs: [SyncStatus.pendingDelete.name],
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToHive).toList();
  }

  @override
  Future<Hive?> getHiveById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'hives',
      where: '(local_id = ? OR server_id = ?) AND sync_status != ?',
      whereArgs: [id, id, SyncStatus.pendingDelete.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToHive(rows.first);
  }

  @override
  Future<void> saveServerHives(List<Hive> hives) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final hive in hives) {
        final serverId = hive.serverId ?? hive.id;
        final existing = await txn.query(
          'hives',
          where: 'server_id = ?',
          whereArgs: [serverId],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final currentSyncStatus = existing.first['sync_status'] as String?;
          // Never overwrite pending updates or pending deletes with remote state
          if (currentSyncStatus == SyncStatus.pendingUpdate.name ||
              currentSyncStatus == SyncStatus.pendingDelete.name) {
            continue;
          }
          await txn.update(
            'hives',
            {
              'apiary_server_id': hive.apiaryServerId ?? hive.apiaryId,
              'name': hive.name,
              'notes': hive.notes,
              'images': jsonEncode(hive.images),
              'created_at': hive.createdAt.toIso8601String(),
              'updated_at': hive.updatedAt.toIso8601String(),
              'sync_status': SyncStatus.synced.name,
            },
            where: 'server_id = ?',
            whereArgs: [serverId],
          );
        } else {
          final localId = hive.localId ?? serverId;
          await txn.insert('hives', {
            'local_id': localId,
            'server_id': serverId,
            'apiary_local_id': hive.apiaryLocalId,
            'apiary_server_id': hive.apiaryServerId ?? hive.apiaryId,
            'name': hive.name,
            'notes': hive.notes,
            'images': jsonEncode(hive.images),
            'created_at': hive.createdAt.toIso8601String(),
            'updated_at': hive.updatedAt.toIso8601String(),
            'sync_status': SyncStatus.synced.name,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  @override
  Future<Hive> insertHive(Hive hive) async {
    final db = await _db;
    final row = _hiveToRow(hive);
    await db.insert('hives', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return hive;
  }

  @override
  Future<Hive> updateHive(Hive hive) async {
    final db = await _db;
    final localId = hive.localId ?? hive.id;
    final row = _hiveToRow(hive);
    await db.update(
      'hives',
      row,
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [localId, localId],
    );
    return hive;
  }

  @override
  Future<void> deleteHivePermanently(String localId) async {
    final db = await _db;
    await db.delete(
      'hives',
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [localId, localId],
    );
  }

  @override
  Future<void> markPendingDelete(String id) async {
    final db = await _db;
    await db.update(
      'hives',
      {'sync_status': SyncStatus.pendingDelete.name},
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [id, id],
    );
  }

  @override
  Future<List<Hive>> getPendingSyncHives() async {
    final db = await _db;
    final rows = await db.query(
      'hives',
      where: 'sync_status IN (?, ?, ?)',
      whereArgs: [
        SyncStatus.pendingCreate.name,
        SyncStatus.pendingUpdate.name,
        SyncStatus.pendingDelete.name,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToHive).toList();
  }

  @override
  Future<List<Hive>> getPendingSyncHivesForApiary(String apiaryId) async {
    final db = await _db;
    final rows = await db.query(
      'hives',
      where:
          '(apiary_local_id = ? OR apiary_server_id = ?) AND sync_status IN (?, ?, ?)',
      whereArgs: [
        apiaryId,
        apiaryId,
        SyncStatus.pendingCreate.name,
        SyncStatus.pendingUpdate.name,
        SyncStatus.pendingDelete.name,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToHive).toList();
  }

  @override
  Future<void> markSynced({
    required String localId,
    required String serverId,
    List<String>? images,
  }) async {
    final db = await _db;
    await db.update(
      'hives',
      {
        'server_id': serverId,
        'sync_status': SyncStatus.synced.name,
        if (images != null) 'images': jsonEncode(images),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  @override
  Future<void> resolveApiaryServerId({
    required String apiaryLocalId,
    required String apiaryServerId,
  }) async {
    final db = await _db;
    await db.update(
      'hives',
      {'apiary_server_id': apiaryServerId},
      where: 'apiary_local_id = ?',
      whereArgs: [apiaryLocalId],
    );
  }

  @override
  Future<void> deleteHivesByApiaryLocalId(String apiaryLocalId) async {
    final db = await _db;
    await db.delete(
      'hives',
      where: 'apiary_local_id = ?',
      whereArgs: [apiaryLocalId],
    );
  }

  @override
  Future<List<Hive>> getHivesByApiaryId(String apiaryId) async {
    final db = await _db;
    final rows = await db.query(
      'hives',
      where: 'apiary_local_id = ? OR apiary_server_id = ?',
      whereArgs: [apiaryId, apiaryId],
    );
    return rows.map(_rowToHive).toList();
  }

  @override
  Future<void> deleteHivesByApiaryId(String apiaryId) async {
    final db = await _db;
    await db.delete(
      'hives',
      where: 'apiary_local_id = ? OR apiary_server_id = ?',
      whereArgs: [apiaryId, apiaryId],
    );
  }

  // --- Mapping helpers ---

  static Hive _rowToHive(Map<String, dynamic> row) {
    final imagesJson = row['images'] as String? ?? '[]';
    List<String> images = const [];
    try {
      final decoded = jsonDecode(imagesJson);
      if (decoded is List) {
        images = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    final localId = row['local_id'] as String;
    final serverId = row['server_id'] as String?;
    final apiaryLocalId = row['apiary_local_id'] as String?;
    final apiaryServerId = row['apiary_server_id'] as String?;
    final syncStatusStr = row['sync_status'] as String? ?? 'synced';
    final syncStatus = SyncStatus.values.firstWhere(
      (s) => s.name == syncStatusStr,
      orElse: () => SyncStatus.synced,
    );

    return Hive(
      id: serverId ?? localId,
      apiaryId: apiaryServerId ?? apiaryLocalId ?? '',
      name: row['name'] as String,
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      images: images,
      localId: localId,
      serverId: serverId,
      apiaryLocalId: apiaryLocalId,
      apiaryServerId: apiaryServerId,
      syncStatus: syncStatus,
    );
  }

  static Map<String, dynamic> _hiveToRow(Hive hive) {
    final localId = hive.localId ?? hive.id;
    final serverId =
        hive.serverId ??
        (hive.syncStatus == SyncStatus.synced ? hive.id : null);
    final apiaryServerId =
        hive.apiaryServerId ??
        (hive.apiaryLocalId == null ? hive.apiaryId : null);
    return {
      'local_id': localId,
      'server_id': serverId,
      'apiary_local_id': hive.apiaryLocalId,
      'apiary_server_id': apiaryServerId,
      'name': hive.name,
      'notes': hive.notes,
      'images': jsonEncode(hive.images),
      'created_at': hive.createdAt.toIso8601String(),
      'updated_at': hive.updatedAt.toIso8601String(),
      'sync_status': hive.syncStatus.name,
    };
  }
}
