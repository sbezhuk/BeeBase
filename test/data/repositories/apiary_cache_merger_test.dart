import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/repositories/apiary_cache_merger.dart';
import 'package:beebase/domain/enum/local/apiary_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const merger = ApiaryCacheMerger();

  final serverItem = ApiaryResponse(id: 'apiary-1', name: 'Back Garden', createdAt: DateTime(2026), updatedAt: DateTime(2026));
  final pendingLocal = ApiaryResponse(
    id: 'local-pending-1',
    name: 'New Yard',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  OfflineOperation pendingOp(String localEntityId, {OperationStatus status = OperationStatus.pending}) {
    return OfflineOperation(
      id: 'op-1',
      entityType: 'apiary',
      operationType: OperationType.create,
      payload: const {},
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      localEntityId: localEntityId,
    );
  }

  group('mergeFirstPage', () {
    test('replaces the old cache with the fresh server page', () {
      final stale = ApiaryResponse(id: 'stale', name: 'Stale', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      final merged = merger.mergeFirstPage([serverItem], [stale], const []);
      expect(merged.map((response) => response.id), ['apiary-1']);
    });

    test('keeps a not-yet-synced local placeholder alongside the fresh server page', () {
      final merged = merger.mergeFirstPage([serverItem], [pendingLocal], [pendingOp('local-pending-1')]);
      expect(merged.map((response) => response.id), ['apiary-1', 'local-pending-1']);
    });

    test('drops a local placeholder once its operation is synced', () {
      final merged = merger.mergeFirstPage([serverItem], [pendingLocal], [
        pendingOp('local-pending-1', status: OperationStatus.synced),
      ]);
      expect(merged.map((response) => response.id), ['apiary-1']);
    });

    test('a pending UPDATE on a synced id is not duplicated against the stale server copy', () {
      final editedLocally = ApiaryResponse(id: 'apiary-1', name: 'Renamed Locally', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      final updateOp = OfflineOperation(
        id: 'op-2',
        entityType: 'apiary',
        operationType: OperationType.update,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'apiary-1',
      );

      final merged = merger.mergeFirstPage([serverItem], [editedLocally], [updateOp]);

      expect(merged.length, 1);
      expect(merged.single.name, 'Renamed Locally');
    });
  });

  group('appendPage', () {
    test('appends the fresh page after the existing cache, preserving order', () {
      final second = ApiaryResponse(id: 'apiary-2', name: 'Meadow', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      final merged = merger.appendPage([second], [serverItem]);
      expect(merged.map((response) => response.id), ['apiary-1', 'apiary-2']);
    });

    test('dedupes an item that appears in both the old cache and the fresh page', () {
      final merged = merger.appendPage([serverItem], [serverItem]);
      expect(merged.map((response) => response.id), ['apiary-1']);
    });

    test('never re-adds a pending placeholder — it stays wherever it already was in the cache', () {
      final merged = merger.appendPage([serverItem], [pendingLocal]);
      expect(merged.map((response) => response.id), ['local-pending-1', 'apiary-1']);
    });
  });

  group('toEntities', () {
    test('tags a pending id as ApiarySyncStatus.pending and everything else as synced', () {
      final entities = merger.toEntities([serverItem, pendingLocal], [pendingOp('local-pending-1')]);
      final synced = entities.firstWhere((apiary) => apiary.id == 'apiary-1');
      final pending = entities.firstWhere((apiary) => apiary.id == 'local-pending-1');
      expect(synced.syncStatus, ApiarySyncStatus.synced);
      expect(pending.syncStatus, ApiarySyncStatus.pending);
    });
  });
}
