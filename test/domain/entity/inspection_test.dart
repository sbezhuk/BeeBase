import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inspection1 = Inspection(
    id: 'inspection-1',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final inspection2 = Inspection(
    id: 'inspection-1',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final inspection3 = Inspection(
    id: 'inspection-2',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.health,
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('equality and hashCode', () {
    test('same-field instances are equal and have identical hashCodes', () {
      expect(inspection1, inspection2);
      expect(inspection1.hashCode, inspection2.hashCode);
    });

    test('instances with different fields are not equal', () {
      expect(inspection1 == inspection3, isFalse);
    });
  });

  group('existsOnServer', () {
    test(
      'is false only for an inspection created offline and never synced',
      () {
        expect(
          inspection1
              .copyWith(syncStatus: SyncStatus.pendingCreate)
              .existsOnServer,
          isFalse,
        );
      },
    );

    test('is true for every status that implies a server counterpart', () {
      const serverBacked = [
        SyncStatus.synced,
        SyncStatus.pendingUpdate,
        SyncStatus.pendingDelete,
        SyncStatus.syncing,
      ];
      for (final status in serverBacked) {
        expect(
          inspection1.copyWith(syncStatus: status).existsOnServer,
          isTrue,
          reason: status.name,
        );
      }
    });
  });
}
