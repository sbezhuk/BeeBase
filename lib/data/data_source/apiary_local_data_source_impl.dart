import 'dart:convert';

import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:sqflite/sqflite.dart';

final class ApiaryLocalDataSourceImpl implements IApiaryLocalDataSource {
  ApiaryLocalDataSourceImpl({required ApiaryDatabase database})
      : _apiaryDatabase = database;

  final ApiaryDatabase _apiaryDatabase;

  Future<Database> get _db => _apiaryDatabase.database;

  @override
  Future<List<Apiary>> getActiveApiaries({
    required int page,
    required int limit,
  }) async {
    final db = await _db;
    final offset = (page - 1) * limit;
    final rows = await db.query(
      'apiaries',
      where: 'sync_status != ?',
      whereArgs: [SyncStatus.pendingDelete.name],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_rowToApiary).toList();
  }

  @override
  Future<Apiary?> getApiaryById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'apiaries',
      where: '(local_id = ? OR server_id = ?) AND sync_status != ?',
      whereArgs: [id, id, SyncStatus.pendingDelete.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToApiary(rows.first);
  }

  @override
  Future<void> saveServerApiaries(List<Apiary> apiaries) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final apiary in apiaries) {
        final serverId = apiary.serverId ?? apiary.id;
        final existing = await txn.query(
          'apiaries',
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
            'apiaries',
            {
              'name': apiary.name,
              'description': apiary.description,
              'location': apiary.location,
              'lat': apiary.lat,
              'lon': apiary.lon,
              'images': jsonEncode(apiary.images),
              'created_at': apiary.createdAt.toIso8601String(),
              'updated_at': apiary.updatedAt.toIso8601String(),
              'sync_status': SyncStatus.synced.name,
            },
            where: 'server_id = ?',
            whereArgs: [serverId],
          );
        } else {
          final localId = apiary.localId ?? serverId;
          await txn.insert(
            'apiaries',
            {
              'local_id': localId,
              'server_id': serverId,
              'name': apiary.name,
              'description': apiary.description,
              'location': apiary.location,
              'lat': apiary.lat,
              'lon': apiary.lon,
              'images': jsonEncode(apiary.images),
              'created_at': apiary.createdAt.toIso8601String(),
              'updated_at': apiary.updatedAt.toIso8601String(),
              'sync_status': SyncStatus.synced.name,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  @override
  Future<Apiary> insertApiary(Apiary apiary) async {
    final db = await _db;
    final row = _apiaryToRow(apiary);
    await db.insert(
      'apiaries',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return apiary;
  }

  @override
  Future<Apiary> updateApiary(Apiary apiary) async {
    final db = await _db;
    final localId = apiary.localId ?? apiary.id;
    final row = _apiaryToRow(apiary);
    await db.update(
      'apiaries',
      row,
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [localId, localId],
    );
    return apiary;
  }

  @override
  Future<void> deleteApiaryPermanently(String localId) async {
    final db = await _db;
    await db.delete(
      'apiaries',
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [localId, localId],
    );
  }

  @override
  Future<void> markPendingDelete(String id) async {
    final db = await _db;
    await db.update(
      'apiaries',
      {'sync_status': SyncStatus.pendingDelete.name},
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [id, id],
    );
  }

  @override
  Future<List<Apiary>> getPendingSyncApiaries() async {
    final db = await _db;
    final rows = await db.query(
      'apiaries',
      where: 'sync_status IN (?, ?, ?)',
      whereArgs: [
        SyncStatus.pendingCreate.name,
        SyncStatus.pendingUpdate.name,
        SyncStatus.pendingDelete.name,
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToApiary).toList();
  }

  @override
  Future<void> markSynced({
    required String localId,
    required String serverId,
    List<String>? images,
  }) async {
    final db = await _db;
    await db.update(
      'apiaries',
      {
        'server_id': serverId,
        'sync_status': SyncStatus.synced.name,
        if (images != null) 'images': jsonEncode(images),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // --- Local Media Methods ---

  @override
  Future<void> saveLocalMedia(LocalMedia media) async {
    final db = await _db;
    await db.insert(
      'local_media',
      media.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<LocalMedia>> getLocalMediaForOwner(String ownerId) async {
    final db = await _db;
    final rows = await db.query(
      'local_media',
      where: 'owner_id = ? AND sync_status != ?',
      whereArgs: [ownerId, SyncStatus.pendingDelete.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalMedia.fromMap).toList();
  }

  @override
  Future<LocalMedia?> getLocalMediaById(String localId) async {
    final db = await _db;
    final rows = await db.query(
      'local_media',
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [localId, localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalMedia.fromMap(rows.first);
  }

  @override
  Future<void> updateLocalMediaStatus(
    String localId,
    SyncStatus status, {
    String? serverId,
  }) async {
    final db = await _db;
    await db.update(
      'local_media',
      {
        'sync_status': status.name,
        if (serverId != null) 'server_id': serverId,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  @override
  Future<void> deleteLocalMedia(String localId) async {
    final db = await _db;
    await db.delete(
      'local_media',
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [localId, localId],
    );
  }

  @override
  Future<List<LocalMedia>> getPendingMedia() async {
    final db = await _db;
    final rows = await db.query(
      'local_media',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingCreate.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalMedia.fromMap).toList();
  }

  // --- Mapping helpers ---

  static Apiary _rowToApiary(Map<String, dynamic> row) {
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
    final syncStatusStr = row['sync_status'] as String? ?? 'synced';
    final syncStatus = SyncStatus.values.firstWhere(
      (s) => s.name == syncStatusStr,
      orElse: () => SyncStatus.synced,
    );

    return Apiary(
      id: serverId ?? localId,
      name: row['name'] as String,
      description: row['description'] as String?,
      location: row['location'] as String?,
      lat: (row['lat'] as num?)?.toDouble(),
      lon: (row['lon'] as num?)?.toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      images: images,
      localId: localId,
      serverId: serverId,
      syncStatus: syncStatus,
    );
  }

  static Map<String, dynamic> _apiaryToRow(Apiary apiary) {
    final localId = apiary.localId ?? apiary.id;
    final serverId = apiary.serverId ??
        (apiary.syncStatus == SyncStatus.synced ? apiary.id : null);
    return {
      'local_id': localId,
      'server_id': serverId,
      'name': apiary.name,
      'description': apiary.description,
      'location': apiary.location,
      'lat': apiary.lat,
      'lon': apiary.lon,
      'images': jsonEncode(apiary.images),
      'created_at': apiary.createdAt.toIso8601String(),
      'updated_at': apiary.updatedAt.toIso8601String(),
      'sync_status': apiary.syncStatus.name,
    };
  }
}
