import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_sync_status.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Inspection buildInspection({
    String id = 'inspection-1',
    InspectionSyncStatus syncStatus = InspectionSyncStatus.synced,
  }) {
    return Inspection(
      id: id,
      hiveId: 'hive-1',
      date: DateTime(2026, 1, 1),
      type: InspectionType.routine,
      notes: 'notes',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      syncStatus: syncStatus,
    );
  }

  test('isLocalOnly is true for a locally-generated id', () {
    final inspection = buildInspection(id: LocalIdGenerator.generate());
    expect(inspection.isLocalOnly, isTrue);
  });

  test('isLocalOnly is false for a server-assigned id', () {
    expect(buildInspection().isLocalOnly, isFalse);
  });

  test('copyWith replaces only syncStatus', () {
    final inspection = buildInspection();
    final updated = inspection.copyWith(syncStatus: InspectionSyncStatus.pending);
    expect(updated.syncStatus, InspectionSyncStatus.pending);
    expect(updated.id, inspection.id);
    expect(updated.hiveId, inspection.hiveId);
    expect(updated.date, inspection.date);
  });

  test('equality and hashCode are based on all fields', () {
    expect(buildInspection(), buildInspection());
    expect(buildInspection().hashCode, buildInspection().hashCode);
    expect(buildInspection(), isNot(buildInspection(syncStatus: InspectionSyncStatus.pending)));
  });
}
