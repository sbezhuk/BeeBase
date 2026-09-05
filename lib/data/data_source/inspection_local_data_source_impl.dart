import 'dart:convert';

import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:sqflite/sqflite.dart';

final class InspectionLocalDataSourceImpl implements IInspectionLocalDataSource {
  InspectionLocalDataSourceImpl({required ApiaryDatabase database}) : _apiaryDatabase = database;

  final ApiaryDatabase _apiaryDatabase;

  Future<Database> get _db => _apiaryDatabase.database;

  @override
  Future<List<Inspection>> getActiveInspectionsForHive({required String hiveId, required int page, required int limit}) async {
    final db = await _db;
    final offset = (page - 1) * limit;
    final rows = await db.query(
      'inspections',
      where: '(hive_local_id = ? OR hive_server_id = ?) AND sync_status != ?',
      whereArgs: [hiveId, hiveId, SyncStatus.pendingDelete.name],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_rowToInspection).toList();
  }

  @override
  Future<Inspection?> getInspectionById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'inspections',
      where: '(local_id = ? OR server_id = ?) AND sync_status != ?',
      whereArgs: [id, id, SyncStatus.pendingDelete.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToInspection(rows.first);
  }

  @override
  Future<void> saveServerInspections(List<Inspection> inspections) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final inspection in inspections) {
        final serverId = inspection.serverId ?? inspection.id;
        final existing = await txn.query('inspections', where: 'server_id = ?', whereArgs: [serverId], limit: 1);

        if (existing.isNotEmpty) {
          final currentSyncStatus = existing.first['sync_status'] as String?;
          // Never overwrite pending updates or pending deletes with remote state
          if (currentSyncStatus == SyncStatus.pendingUpdate.name || currentSyncStatus == SyncStatus.pendingDelete.name) {
            continue;
          }
          await txn.update(
            'inspections',
            {
              'hive_server_id': inspection.hiveServerId ?? inspection.hiveId,
              'inspected_at': inspection.date.toIso8601String(),
              'type': inspection.type.name,
              'notes': inspection.notes,
              'images': jsonEncode(inspection.images),
              'created_at': inspection.createdAt.toIso8601String(),
              'updated_at': inspection.updatedAt.toIso8601String(),
              'sync_status': SyncStatus.synced.name,
            },
            where: 'server_id = ?',
            whereArgs: [serverId],
          );
        } else {
          final localId = inspection.localId ?? serverId;
          await txn.insert('inspections', {
            'local_id': localId,
            'server_id': serverId,
            'hive_local_id': inspection.hiveLocalId,
            'hive_server_id': inspection.hiveServerId ?? inspection.hiveId,
            'inspected_at': inspection.date.toIso8601String(),
            'type': inspection.type.name,
            'notes': inspection.notes,
            'images': jsonEncode(inspection.images),
            'created_at': inspection.createdAt.toIso8601String(),
            'updated_at': inspection.updatedAt.toIso8601String(),
            'sync_status': SyncStatus.synced.name,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  @override
  Future<Inspection> insertInspection(Inspection inspection) async {
    final db = await _db;
    final row = _inspectionToRow(inspection);
    await db.insert('inspections', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return inspection;
  }

  @override
  Future<Inspection> updateInspection(Inspection inspection) async {
    final db = await _db;
    final localId = inspection.localId ?? inspection.id;
    final row = _inspectionToRow(inspection);
    await db.update('inspections', row, where: 'local_id = ? OR server_id = ?', whereArgs: [localId, localId]);
    return inspection;
  }

  @override
  Future<void> deleteInspectionPermanently(String localId) async {
    final db = await _db;
    await db.delete('inspections', where: 'local_id = ? OR server_id = ?', whereArgs: [localId, localId]);
  }

  @override
  Future<void> markPendingDelete(String id) async {
    final db = await _db;
    await db.update(
      'inspections',
      {'sync_status': SyncStatus.pendingDelete.name},
      where: 'local_id = ? OR server_id = ?',
      whereArgs: [id, id],
    );
  }

  @override
  Future<List<Inspection>> getPendingSyncInspections() async {
    final db = await _db;
    final rows = await db.query(
      'inspections',
      where: 'sync_status IN (?, ?, ?)',
      whereArgs: [SyncStatus.pendingCreate.name, SyncStatus.pendingUpdate.name, SyncStatus.pendingDelete.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToInspection).toList();
  }

  @override
  Future<List<Inspection>> getPendingSyncInspectionsForHive(String hiveId) async {
    final db = await _db;
    final rows = await db.query(
      'inspections',
      where: '(hive_local_id = ? OR hive_server_id = ?) AND sync_status IN (?, ?, ?)',
      whereArgs: [hiveId, hiveId, SyncStatus.pendingCreate.name, SyncStatus.pendingUpdate.name, SyncStatus.pendingDelete.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToInspection).toList();
  }

  @override
  Future<void> markSynced({required String localId, required String serverId, List<String>? images}) async {
    final db = await _db;
    await db.update(
      'inspections',
      {'server_id': serverId, 'sync_status': SyncStatus.synced.name, if (images != null) 'images': jsonEncode(images)},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  @override
  Future<void> resolveHiveServerId({required String hiveLocalId, required String hiveServerId}) async {
    final db = await _db;
    await db.update('inspections', {'hive_server_id': hiveServerId}, where: 'hive_local_id = ?', whereArgs: [hiveLocalId]);
  }

  @override
  Future<List<Inspection>> getInspectionsByHiveId(String hiveId) async {
    final db = await _db;
    final rows = await db.query('inspections', where: 'hive_local_id = ? OR hive_server_id = ?', whereArgs: [hiveId, hiveId]);
    return rows.map(_rowToInspection).toList();
  }

  @override
  Future<void> deleteInspectionsByHiveId(String hiveId) async {
    final db = await _db;
    await db.delete('inspections', where: 'hive_local_id = ? OR hive_server_id = ?', whereArgs: [hiveId, hiveId]);
  }

  // --- Mapping helpers ---

  static Inspection _rowToInspection(Map<String, dynamic> row) {
    final localId = row['local_id'] as String;
    final serverId = row['server_id'] as String?;
    final hiveLocalId = row['hive_local_id'] as String?;
    final hiveServerId = row['hive_server_id'] as String?;
    final syncStatusStr = row['sync_status'] as String? ?? 'synced';
    final syncStatus = SyncStatus.values.firstWhere((s) => s.name == syncStatusStr, orElse: () => SyncStatus.synced);
    final type = InspectionType.values.firstWhere((t) => t.name == row['type'] as String, orElse: () => InspectionType.routine);

    final imagesJson = row['images'] as String? ?? '[]';
    List<String> images = const [];
    try {
      final decoded = jsonDecode(imagesJson);
      if (decoded is List) {
        images = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return Inspection(
      id: serverId ?? localId,
      hiveId: hiveServerId ?? hiveLocalId ?? '',
      date: DateTime.parse(row['inspected_at'] as String),
      type: type,
      notes: row['notes'] as String,
      images: images,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      localId: localId,
      serverId: serverId,
      hiveLocalId: hiveLocalId,
      hiveServerId: hiveServerId,
      syncStatus: syncStatus,
    );
  }

  static Map<String, dynamic> _inspectionToRow(Inspection inspection) {
    final localId = inspection.localId ?? inspection.id;
    final serverId = inspection.serverId ?? (inspection.syncStatus == SyncStatus.synced ? inspection.id : null);
    final hiveServerId = inspection.hiveServerId ?? (inspection.hiveLocalId == null ? inspection.hiveId : null);
    return {
      'local_id': localId,
      'server_id': serverId,
      'hive_local_id': inspection.hiveLocalId,
      'hive_server_id': hiveServerId,
      'inspected_at': inspection.date.toIso8601String(),
      'type': inspection.type.name,
      'notes': inspection.notes,
      'images': jsonEncode(inspection.images),
      'created_at': inspection.createdAt.toIso8601String(),
      'updated_at': inspection.updatedAt.toIso8601String(),
      'sync_status': inspection.syncStatus.name,
    };
  }
}
