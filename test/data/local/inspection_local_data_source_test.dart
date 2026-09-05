import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/inspection_local_data_source_impl.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}

class MockTransaction extends Mock implements Transaction {}

void main() {
  late MockDatabase db;
  late ApiaryDatabase apiaryDatabase;
  late InspectionLocalDataSourceImpl localDataSource;

  setUpAll(() {
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  setUp(() {
    db = MockDatabase();
    apiaryDatabase = ApiaryDatabase(database: db);
    localDataSource = InspectionLocalDataSourceImpl(database: apiaryDatabase);
  });

  final sampleInspection = Inspection(
    id: 'local-1',
    hiveId: 'hive-local-1',
    localId: 'local-1',
    hiveLocalId: 'hive-local-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'A test note',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final sampleRow = {
    'local_id': 'local-1',
    'server_id': null,
    'hive_local_id': 'hive-local-1',
    'hive_server_id': null,
    'inspected_at': DateTime(2026, 1, 1).toIso8601String(),
    'type': 'routine',
    'notes': 'A test note',
    'images': '["media-1","media-2"]',
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    'sync_status': 'pendingCreate',
  };

  group('InspectionLocalDataSourceImpl', () {
    test('insertInspection calls db.insert and returns inspection', () async {
      when(() => db.insert('inspections', any(), conflictAlgorithm: any(named: 'conflictAlgorithm'))).thenAnswer((_) async => 1);

      final result = await localDataSource.insertInspection(sampleInspection);
      expect(result.id, 'local-1');
      verify(
        () => db.insert(
          'inspections',
          any(
            that: allOf(
              containsPair('local_id', 'local-1'),
              containsPair('hive_local_id', 'hive-local-1'),
              containsPair('hive_server_id', null),
              containsPair('type', 'routine'),
            ),
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);
    });

    test('getInspectionById returns mapped Inspection when found, deriving '
        'hiveId from hiveLocalId', () async {
      when(
        () => db.query(
          'inspections',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          limit: 1,
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getInspectionById('local-1');
      expect(result, isNotNull);
      expect(result!.id, 'local-1');
      expect(result.hiveId, 'hive-local-1');
      expect(result.type, InspectionType.routine);
      expect(result.syncStatus, SyncStatus.pendingCreate);
      expect(result.images, ['media-1', 'media-2']);
    });

    test('getActiveInspectionsForHive matches either hive_local_id or hive_server_id', () async {
      when(
        () => db.query(
          'inspections',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getActiveInspectionsForHive(hiveId: 'hive-local-1', page: 1, limit: 10);
      expect(result.length, 1);
      verify(
        () => db.query(
          'inspections',
          where: '(hive_local_id = ? OR hive_server_id = ?) AND sync_status != ?',
          whereArgs: ['hive-local-1', 'hive-local-1', SyncStatus.pendingDelete.name],
          orderBy: 'created_at DESC',
          limit: 10,
          offset: 0,
        ),
      ).called(1);
    });

    test('markPendingDelete sets status to pendingDelete', () async {
      when(
        () => db.update(
          'inspections',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.markPendingDelete('local-1');
      verify(
        () => db.update(
          'inspections',
          {'sync_status': SyncStatus.pendingDelete.name},
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['local-1', 'local-1'],
        ),
      ).called(1);
    });

    test('deleteInspectionPermanently removes row from database', () async {
      when(
        () => db.delete(
          'inspections',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.deleteInspectionPermanently('local-1');
      verify(() => db.delete('inspections', where: 'local_id = ? OR server_id = ?', whereArgs: ['local-1', 'local-1'])).called(1);
    });

    test('getPendingSyncInspections queries pendingCreate, pendingUpdate, and pendingDelete', () async {
      when(
        () => db.query(
          'inspections',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getPendingSyncInspections();
      expect(result.length, 1);
      verify(
        () => db.query(
          'inspections',
          where: 'sync_status IN (?, ?, ?)',
          whereArgs: [SyncStatus.pendingCreate.name, SyncStatus.pendingUpdate.name, SyncStatus.pendingDelete.name],
          orderBy: 'created_at ASC',
        ),
      ).called(1);
    });

    test('markSynced updates serverId and sync_status', () async {
      when(
        () => db.update(
          'inspections',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.markSynced(localId: 'local-1', serverId: 'server-1');

      verify(
        () => db.update(
          'inspections',
          {'server_id': 'server-1', 'sync_status': SyncStatus.synced.name},
          where: 'local_id = ?',
          whereArgs: ['local-1'],
        ),
      ).called(1);
    });

    test('markSynced with images persists the server canonical image id list', () async {
      when(
        () => db.update(
          'inspections',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.markSynced(localId: 'local-1', serverId: 'server-1', images: ['media-1', 'media-2']);

      verify(
        () => db.update(
          'inspections',
          {'server_id': 'server-1', 'sync_status': SyncStatus.synced.name, 'images': '["media-1","media-2"]'},
          where: 'local_id = ?',
          whereArgs: ['local-1'],
        ),
      ).called(1);
    });

    test('insertInspection encodes images as a JSON list', () async {
      when(() => db.insert('inspections', any(), conflictAlgorithm: any(named: 'conflictAlgorithm'))).thenAnswer((_) async => 1);

      final inspectionWithImages = sampleInspection.copyWith(images: ['media-1', 'media-2']);
      await localDataSource.insertInspection(inspectionWithImages);

      verify(
        () => db.insert(
          'inspections',
          any(that: containsPair('images', '["media-1","media-2"]')),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);
    });

    test('resolveHiveServerId updates every inspection tracking that local hive', () async {
      when(
        () => db.update(
          'inspections',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 2);

      await localDataSource.resolveHiveServerId(hiveLocalId: 'hive-local-1', hiveServerId: 'hive-server-1');

      verify(
        () => db.update(
          'inspections',
          {'hive_server_id': 'hive-server-1'},
          where: 'hive_local_id = ?',
          whereArgs: ['hive-local-1'],
        ),
      ).called(1);
    });

    test('getInspectionsByHiveId matches either hive_local_id or hive_server_id, '
        'regardless of sync status', () async {
      when(
        () => db.query(
          'inspections',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getInspectionsByHiveId('hive-1');
      expect(result.length, 1);
      verify(
        () => db.query('inspections', where: 'hive_local_id = ? OR hive_server_id = ?', whereArgs: ['hive-1', 'hive-1']),
      ).called(1);
    });

    test('deleteInspectionsByHiveId removes every inspection under that hive', () async {
      when(
        () => db.delete(
          'inspections',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 2);

      await localDataSource.deleteInspectionsByHiveId('hive-1');
      verify(
        () => db.delete('inspections', where: 'hive_local_id = ? OR hive_server_id = ?', whereArgs: ['hive-1', 'hive-1']),
      ).called(1);
    });
  });
}
