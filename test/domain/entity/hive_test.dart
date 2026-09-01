import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/local/hive_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Hive buildHive({
    String id = 'hive-1',
    HiveSyncStatus syncStatus = HiveSyncStatus.synced,
  }) {
    return Hive(
      id: id,
      apiaryId: 'apiary-1',
      name: 'Hive 1',
      notes: 'notes',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      syncStatus: syncStatus,
    );
  }

  test('isLocalOnly is true for a locally-generated id', () {
    final hive = buildHive(id: LocalIdGenerator.generate());
    expect(hive.isLocalOnly, isTrue);
  });

  test('isLocalOnly is false for a server-assigned id', () {
    expect(buildHive().isLocalOnly, isFalse);
  });

  test('copyWith replaces only syncStatus', () {
    final hive = buildHive();
    final updated = hive.copyWith(syncStatus: HiveSyncStatus.pending);
    expect(updated.syncStatus, HiveSyncStatus.pending);
    expect(updated.id, hive.id);
    expect(updated.apiaryId, hive.apiaryId);
    expect(updated.name, hive.name);
  });

  test('equality and hashCode are based on all fields', () {
    expect(buildHive(), buildHive());
    expect(buildHive().hashCode, buildHive().hashCode);
    expect(buildHive(), isNot(buildHive(syncStatus: HiveSyncStatus.pending)));
  });
}
