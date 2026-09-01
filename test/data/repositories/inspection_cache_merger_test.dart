import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/repositories/inspection_cache_merger.dart';
import 'package:beebase/domain/enum/inspection_sync_status.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const merger = InspectionCacheMerger();

  final serverItem = InspectionResponse(
    id: 'inspection-1',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final pendingLocal = InspectionResponse(
    id: 'local-pending-1',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 2),
    type: InspectionType.routine,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  OfflineOperation pendingOp(
    String localEntityId, {
    OperationStatus status = OperationStatus.pending,
  }) {
    return OfflineOperation(
      id: 'op-1',
      entityType: 'inspection',
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
      final stale = InspectionResponse(
        id: 'stale',
        hiveId: 'hive-1',
        date: DateTime(2026),
        type: InspectionType.routine,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final merged = merger.mergeFirstPage([serverItem], [stale], const []);
      expect(merged.map((response) => response.id), ['inspection-1']);
    });

    test('keeps a not-yet-synced local placeholder alongside the fresh server page', () {
      final merged = merger.mergeFirstPage([serverItem], [pendingLocal], [
        pendingOp('local-pending-1'),
      ]);
      expect(merged.map((response) => response.id), ['inspection-1', 'local-pending-1']);
    });

    test('drops a local placeholder once its operation is synced', () {
      final merged = merger.mergeFirstPage([serverItem], [pendingLocal], [
        pendingOp('local-pending-1', status: OperationStatus.synced),
      ]);
      expect(merged.map((response) => response.id), ['inspection-1']);
    });

    test('a pending UPDATE on a synced id is not duplicated against the stale server copy', () {
      final editedLocally = InspectionResponse(
        id: 'inspection-1',
        hiveId: 'hive-1',
        date: DateTime(2026),
        type: InspectionType.routine,
        notes: 'edited',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final updateOp = OfflineOperation(
        id: 'op-2',
        entityType: 'inspection',
        operationType: OperationType.update,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'inspection-1',
      );

      final merged = merger.mergeFirstPage([serverItem], [editedLocally], [updateOp]);

      expect(merged.length, 1);
      expect(merged.single.notes, 'edited');
    });
  });

  group('appendPage', () {
    test('appends the fresh page after the existing cache, preserving order', () {
      final second = InspectionResponse(
        id: 'inspection-2',
        hiveId: 'hive-1',
        date: DateTime(2026),
        type: InspectionType.routine,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final merged = merger.appendPage([second], [serverItem]);
      expect(merged.map((response) => response.id), ['inspection-1', 'inspection-2']);
    });

    test('dedupes an item that appears in both the old cache and the fresh page', () {
      final merged = merger.appendPage([serverItem], [serverItem]);
      expect(merged.map((response) => response.id), ['inspection-1']);
    });

    test('never re-adds a pending placeholder — it stays wherever it already was in the cache', () {
      final merged = merger.appendPage([serverItem], [pendingLocal]);
      expect(merged.map((response) => response.id), ['local-pending-1', 'inspection-1']);
    });
  });

  group('toEntities', () {
    test('tags a pending id as InspectionSyncStatus.pending and everything else as synced', () {
      final entities = merger.toEntities(
        [serverItem, pendingLocal],
        [pendingOp('local-pending-1')],
      );
      final synced = entities.firstWhere((inspection) => inspection.id == 'inspection-1');
      final pending = entities.firstWhere((inspection) => inspection.id == 'local-pending-1');
      expect(synced.syncStatus, InspectionSyncStatus.synced);
      expect(pending.syncStatus, InspectionSyncStatus.pending);
    });
  });
}
