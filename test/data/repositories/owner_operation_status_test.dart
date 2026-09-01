import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/repositories/owner_operation_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OfflineOperation ownOp(String localEntityId, {OperationStatus status = OperationStatus.pending}) {
    return OfflineOperation(
      id: 'own-op',
      entityType: 'apiary',
      operationType: OperationType.create,
      payload: const {},
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      localEntityId: localEntityId,
    );
  }

  OfflineOperation mediaOp(String ownerId, {String id = 'media-op', OperationStatus status = OperationStatus.pending}) {
    return OfflineOperation(
      id: id,
      entityType: 'media',
      operationType: OperationType.create,
      payload: {'owner_id': ownerId},
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      localEntityId: 'local-photo-$id',
    );
  }

  group('combinedOperationStatus', () {
    test('returns null when nothing references this entity id at all', () {
      final status = combinedOperationStatus(entityId: 'apiary-1', operations: [ownOp('apiary-2'), mediaOp('apiary-2')]);
      expect(status, isNull);
    });

    test('reflects the entity\'s own operation when it has no photos', () {
      final status = combinedOperationStatus(entityId: 'apiary-1', operations: [ownOp('apiary-1')]);
      expect(status, OperationStatus.pending);
    });

    test('reflects a pending photo operation even with no operation on the entity itself', () {
      final status = combinedOperationStatus(entityId: 'apiary-1', operations: [mediaOp('apiary-1')]);
      expect(status, OperationStatus.pending);
    });

    test('an operation that only matches by entity type, not id, is ignored', () {
      final status = combinedOperationStatus(entityId: 'apiary-1', operations: [mediaOp('apiary-2')]);
      expect(status, isNull);
    });

    test('a non-media operation type is never matched by owner id, only by localEntityId', () {
      final unrelated = OfflineOperation(
        id: 'other',
        entityType: 'hive',
        operationType: OperationType.create,
        payload: {'owner_id': 'apiary-1'},
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'hive-1',
      );
      final status = combinedOperationStatus(entityId: 'apiary-1', operations: [unrelated]);
      expect(status, isNull);
    });

    test('failed takes priority over a pending operation on the same entity', () {
      final status = combinedOperationStatus(
        entityId: 'apiary-1',
        operations: [
          ownOp('apiary-1', status: OperationStatus.synced),
          mediaOp('apiary-1', status: OperationStatus.failed),
        ],
      );
      expect(status, OperationStatus.failed);
    });

    test('pending takes priority over synced', () {
      final status = combinedOperationStatus(
        entityId: 'apiary-1',
        operations: [
          mediaOp('apiary-1', id: 'photo-1', status: OperationStatus.synced),
          mediaOp('apiary-1', id: 'photo-2', status: OperationStatus.pending),
        ],
      );
      expect(status, OperationStatus.pending);
    });

    test('synced when every relevant operation has synced', () {
      final status = combinedOperationStatus(
        entityId: 'apiary-1',
        operations: [
          ownOp('apiary-1', status: OperationStatus.synced),
          mediaOp('apiary-1', status: OperationStatus.synced),
        ],
      );
      expect(status, OperationStatus.synced);
    });
  });
}
