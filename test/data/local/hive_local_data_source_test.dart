import 'dart:convert';

import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/data/data_source/hive_local_data_source_impl.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}

class MockTransaction extends Mock implements Transaction {}

void main() {
  late MockDatabase db;
  late ApiaryDatabase apiaryDatabase;
  late HiveLocalDataSourceImpl localDataSource;

  setUpAll(() {
    registerFallbackValue(ConflictAlgorithm.replace);
  });

  setUp(() {
    db = MockDatabase();
    apiaryDatabase = ApiaryDatabase(database: db);
    localDataSource = HiveLocalDataSourceImpl(database: apiaryDatabase);
  });

  final sampleHive = Hive(
    id: 'local-1',
    apiaryId: 'apiary-local-1',
    localId: 'local-1',
    apiaryLocalId: 'apiary-local-1',
    name: 'Test Hive',
    notes: 'A test note',
    images: const ['img-1'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    syncStatus: SyncStatus.pendingCreate,
  );

  final sampleRow = {
    'local_id': 'local-1',
    'server_id': null,
    'apiary_local_id': 'apiary-local-1',
    'apiary_server_id': null,
    'name': 'Test Hive',
    'notes': 'A test note',
    'images': jsonEncode(['img-1']),
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    'sync_status': 'pendingCreate',
  };

  group('HiveLocalDataSourceImpl', () {
    test('insertHive calls db.insert and returns hive', () async {
      when(
        () => db.insert(
          'hives',
          any(),
          conflictAlgorithm: any(named: 'conflictAlgorithm'),
        ),
      ).thenAnswer((_) async => 1);

      final result = await localDataSource.insertHive(sampleHive);
      expect(result.id, 'local-1');
      verify(
        () => db.insert(
          'hives',
          any(
            that: allOf(
              containsPair('local_id', 'local-1'),
              containsPair('apiary_local_id', 'apiary-local-1'),
              containsPair('apiary_server_id', null),
            ),
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);
    });

    test(
      'getHiveById returns mapped Hive when found, deriving apiaryId from apiaryLocalId',
      () async {
        when(
          () => db.query(
            'hives',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            limit: 1,
          ),
        ).thenAnswer((_) async => [sampleRow]);

        final result = await localDataSource.getHiveById('local-1');
        expect(result, isNotNull);
        expect(result!.id, 'local-1');
        expect(result.apiaryId, 'apiary-local-1');
        expect(result.name, 'Test Hive');
        expect(result.syncStatus, SyncStatus.pendingCreate);
      },
    );

    test(
      'getActiveHivesForApiary matches either apiary_local_id or apiary_server_id',
      () async {
        when(
          () => db.query(
            'hives',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [sampleRow]);

        final result = await localDataSource.getActiveHivesForApiary(
          apiaryId: 'apiary-local-1',
          page: 1,
          limit: 10,
        );
        expect(result.length, 1);
        verify(
          () => db.query(
            'hives',
            where:
                '(apiary_local_id = ? OR apiary_server_id = ?) AND sync_status != ?',
            whereArgs: [
              'apiary-local-1',
              'apiary-local-1',
              SyncStatus.pendingDelete.name,
            ],
            orderBy: 'created_at DESC',
            limit: 10,
            offset: 0,
          ),
        ).called(1);
      },
    );

    test('markPendingDelete sets status to pendingDelete', () async {
      when(
        () => db.update(
          'hives',
          any(),
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.markPendingDelete('local-1');
      verify(
        () => db.update(
          'hives',
          {'sync_status': SyncStatus.pendingDelete.name},
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['local-1', 'local-1'],
        ),
      ).called(1);
    });

    test('deleteHivePermanently removes row from database', () async {
      when(
        () => db.delete(
          'hives',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      await localDataSource.deleteHivePermanently('local-1');
      verify(
        () => db.delete(
          'hives',
          where: 'local_id = ? OR server_id = ?',
          whereArgs: ['local-1', 'local-1'],
        ),
      ).called(1);
    });

    test(
      'getPendingSyncHives queries pendingCreate, pendingUpdate, and pendingDelete',
      () async {
        when(
          () => db.query(
            'hives',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
          ),
        ).thenAnswer((_) async => [sampleRow]);

        final result = await localDataSource.getPendingSyncHives();
        expect(result.length, 1);
        verify(
          () => db.query(
            'hives',
            where: 'sync_status IN (?, ?, ?)',
            whereArgs: [
              SyncStatus.pendingCreate.name,
              SyncStatus.pendingUpdate.name,
              SyncStatus.pendingDelete.name,
            ],
            orderBy: 'created_at ASC',
          ),
        ).called(1);
      },
    );

    test('markSynced updates serverId, sync_status and images', () async {
      when(
        () => db.update(
          'hives',
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
          'hives',
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

    test(
      'resolveApiaryServerId updates every hive tracking that local apiary',
      () async {
        when(
          () => db.update(
            'hives',
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          ),
        ).thenAnswer((_) async => 2);

        await localDataSource.resolveApiaryServerId(
          apiaryLocalId: 'apiary-local-1',
          apiaryServerId: 'apiary-server-1',
        );

        verify(
          () => db.update(
            'hives',
            {'apiary_server_id': 'apiary-server-1'},
            where: 'apiary_local_id = ?',
            whereArgs: ['apiary-local-1'],
          ),
        ).called(1);
      },
    );

    test(
      'deleteHivesByApiaryLocalId removes every hive under that local apiary',
      () async {
        when(
          () => db.delete(
            'hives',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          ),
        ).thenAnswer((_) async => 2);

        await localDataSource.deleteHivesByApiaryLocalId('apiary-local-1');
        verify(
          () => db.delete(
            'hives',
            where: 'apiary_local_id = ?',
            whereArgs: ['apiary-local-1'],
          ),
        ).called(1);
      },
    );
  });
}
