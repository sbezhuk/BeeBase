import 'dart:convert';

import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/apiary_local_data_source_impl.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}

class MockTransaction extends Mock implements Transaction {}

void main() {
  late MockDatabase db;
  late ApiaryDatabase apiaryDatabase;
  late ApiaryLocalDataSourceImpl localDataSource;

  setUpAll(() {
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  setUp(() {
    db = MockDatabase();
    apiaryDatabase = ApiaryDatabase(database: db);
    localDataSource = ApiaryLocalDataSourceImpl(database: apiaryDatabase);
  });

  final sampleApiary = Apiary(
    id: 'local-1',
    localId: 'local-1',
    name: 'Test Apiary',
    description: 'A test description',
    location: 'Kyiv',
    lat: 50.45,
    lon: 30.52,
    images: const ['img-1'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final sampleRow = {
    'local_id': 'local-1',
    'server_id': null,
    'name': 'Test Apiary',
    'description': 'A test description',
    'location': 'Kyiv',
    'lat': 50.45,
    'lon': 30.52,
    'images': jsonEncode(['img-1']),
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    'sync_status': 'pendingCreate',
  };

  group('ApiaryLocalDataSourceImpl', () {
    test('insertApiary calls db.insert and returns apiary', () async {
      when(
        () => db.insert(
          'apiaries',
          any(),
          conflictAlgorithm: any(named: 'conflictAlgorithm'),
        ),
      ).thenAnswer((_) async => 1);

      final result = await localDataSource.insertApiary(sampleApiary);
      expect(result.id, 'local-1');
      verify(
        () => db.insert(
          'apiaries',
          any(that: containsPair('local_id', 'local-1')),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);
    });

    test('getApiaryById returns mapped Apiary when found', () async {
      when(
        () => db.query(
          'apiaries',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          limit: 1,
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getApiaryById('local-1');
      expect(result, isNotNull);
      expect(result!.id, 'local-1');
      expect(result.name, 'Test Apiary');
      expect(result.syncStatus, SyncStatus.pendingCreate);
    });

    test('getActiveApiaries queries records excluding pendingDelete', () async {
      when(
        () => db.query(
          'apiaries',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getActiveApiaries(page: 1, limit: 10);
      expect(result.length, 1);
      expect(result.first.name, 'Test Apiary');
      verify(
        () => db.query(
          'apiaries',
          where: 'sync_status != ?',
          whereArgs: [SyncStatus.pendingDelete.name],
          orderBy: 'created_at DESC',
          limit: 10,
          offset: 0,
        ),
      ).called(1);
    });

    test('updateApiary updates row in database', () async {
      when(
        () => db.update(
          'apiaries',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      final updated = sampleApiary.copyWith(name: 'New Name');
      final result = await localDataSource.updateApiary(updated);
      expect(result.name, 'New Name');
      verify(
        () => db.update(
          'apiaries',
          any(that: containsPair('name', 'New Name')),
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['local-1', 'local-1'],
        ),
      ).called(1);
    });

    test('markPendingDelete sets status to pendingDelete', () async {
      when(
        () => db.update(
          'apiaries',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.markPendingDelete('local-1');
      verify(
        () => db.update(
          'apiaries',
          {'sync_status': SyncStatus.pendingDelete.name},
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['local-1', 'local-1'],
        ),
      ).called(1);
    });

    test('deleteApiaryPermanently removes row from database', () async {
      when(
        () => db.delete(
          'apiaries',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.deleteApiaryPermanently('local-1');
      verify(
        () => db.delete(
          'apiaries',
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['local-1', 'local-1'],
        ),
      ).called(1);
    });

    test('getPendingSyncApiaries queries pendingCreate, pendingUpdate, and pendingDelete', () async {
      when(
        () => db.query(
          'apiaries',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
        ),
      ).thenAnswer((_) async => [sampleRow]);

      final result = await localDataSource.getPendingSyncApiaries();
      expect(result.length, 1);
      verify(
        () => db.query(
          'apiaries',
          where: 'sync_status IN (?, ?, ?)',
          whereArgs: [
            SyncStatus.pendingCreate.name,
            SyncStatus.pendingUpdate.name,
            SyncStatus.pendingDelete.name,
          ],
          orderBy: 'created_at ASC',
        ),
      ).called(1);
    });

    test('markSynced updates serverId, sync_status and images', () async {
      when(
        () => db.update(
          'apiaries',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.markSynced(
        localId: 'local-1',
        serverId: 'server-1',
        images: ['img-1', 'img-2'],
      );

      verify(
        () => db.update(
          'apiaries',
          {
            'server_id': 'server-1',
            'sync_status': SyncStatus.synced.name,
            'images': jsonEncode(['img-1', 'img-2']),
          },
          where: 'local_id = ?',
          whereArgs: ['local-1'],
        ),
      ).called(1);
    });

    test('LocalMedia operations work as expected', () async {
      final media = LocalMedia(
        localId: 'media-1',
        ownerType: 'apiary',
        ownerId: 'local-1',
        localFilePath: '/path/file.jpg',
        originalFilename: 'file.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 500,
        createdAt: DateTime(2026, 1, 1),
      );

      when(
        () => db.insert(
          'local_media',
          any(),
          conflictAlgorithm: any(named: 'conflictAlgorithm'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.saveLocalMedia(media);
      verify(() => db.insert('local_media', any(), conflictAlgorithm: ConflictAlgorithm.replace)).called(1);

      when(
        () => db.query(
          'local_media',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
        ),
      ).thenAnswer((_) async => [media.toMap()]);

      final ownerMedia = await localDataSource.getLocalMediaForOwner('local-1');
      expect(ownerMedia.length, 1);
      expect(ownerMedia.first.localId, 'media-1');

      when(
        () => db.delete(
          'local_media',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.deleteLocalMedia('media-1');
      verify(
        () => db.delete(
          'local_media',
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['media-1', 'media-1'],
        ),
      ).called(1);
    });
  });
}
