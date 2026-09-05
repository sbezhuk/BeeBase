import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/data/sync/data_synchronizer.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';
import 'package:beebase/data/sync/inspection_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiarySynchronizer extends Mock implements IApiarySynchronizer {}

class MockHiveSynchronizer extends Mock implements IHiveSynchronizer {}

class MockInspectionSynchronizer extends Mock
    implements IInspectionSynchronizer {}

void main() {
  late MockApiarySynchronizer apiarySynchronizer;
  late MockHiveSynchronizer hiveSynchronizer;
  late MockInspectionSynchronizer inspectionSynchronizer;
  late DataSynchronizer dataSynchronizer;

  const cleanInspectionResult = InspectionSyncResult(
    totalPending: 0,
    syncedCount: 0,
    failedCount: 0,
  );

  setUp(() {
    apiarySynchronizer = MockApiarySynchronizer();
    hiveSynchronizer = MockHiveSynchronizer();
    inspectionSynchronizer = MockInspectionSynchronizer();
    dataSynchronizer = DataSynchronizer(
      apiarySynchronizer: apiarySynchronizer,
      hiveSynchronizer: hiveSynchronizer,
      inspectionSynchronizer: inspectionSynchronizer,
    );
    when(
      () => inspectionSynchronizer.syncInspections(),
    ).thenAnswer((_) async => cleanInspectionResult);
  });

  test(
    'syncAll always synchronizes apiaries, then hives, then inspections',
    () async {
      final callOrder = <String>[];
      when(() => apiarySynchronizer.syncApiaries()).thenAnswer((_) async {
        callOrder.add('apiaries');
        return const ApiarySyncResult(
          totalPending: 1,
          syncedCount: 1,
          failedCount: 0,
        );
      });
      when(() => hiveSynchronizer.syncHives()).thenAnswer((_) async {
        callOrder.add('hives');
        return const HiveSyncResult(
          totalPending: 1,
          syncedCount: 1,
          failedCount: 0,
        );
      });
      when(() => inspectionSynchronizer.syncInspections()).thenAnswer((
        _,
      ) async {
        callOrder.add('inspections');
        return const InspectionSyncResult(
          totalPending: 1,
          syncedCount: 1,
          failedCount: 0,
        );
      });

      final result = await dataSynchronizer.syncAll();

      expect(callOrder, ['apiaries', 'hives', 'inspections']);
      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 3);
    },
  );

  test(
    'still runs hive and inspection sync (which will themselves skip dependents) '
    'when apiary sync fails',
    () async {
      when(() => apiarySynchronizer.syncApiaries()).thenAnswer(
        (_) async => const ApiarySyncResult(
          totalPending: 1,
          syncedCount: 0,
          failedCount: 1,
          errors: ['boom'],
        ),
      );
      when(() => hiveSynchronizer.syncHives()).thenAnswer(
        (_) async => const HiveSyncResult(
          totalPending: 1,
          syncedCount: 0,
          failedCount: 0,
          skippedCount: 1,
        ),
      );
      when(() => inspectionSynchronizer.syncInspections()).thenAnswer(
        (_) async => const InspectionSyncResult(
          totalPending: 1,
          syncedCount: 0,
          failedCount: 0,
          skippedCount: 1,
        ),
      );

      final result = await dataSynchronizer.syncAll();

      verify(() => apiarySynchronizer.syncApiaries()).called(1);
      verify(() => hiveSynchronizer.syncHives()).called(1);
      verify(() => inspectionSynchronizer.syncInspections()).called(1);
      expect(result.isSuccess, isFalse);
      expect(result.failedCount, 1);
      expect(result.hives.skippedCount, 1);
      expect(result.inspections.skippedCount, 1);
    },
  );

  test(
    'aggregates totals, failures and errors from all three synchronizers',
    () async {
      when(() => apiarySynchronizer.syncApiaries()).thenAnswer(
        (_) async => const ApiarySyncResult(
          totalPending: 2,
          syncedCount: 1,
          failedCount: 1,
          errors: ['apiary failure'],
        ),
      );
      when(() => hiveSynchronizer.syncHives()).thenAnswer(
        (_) async => const HiveSyncResult(
          totalPending: 3,
          syncedCount: 2,
          failedCount: 1,
          errors: ['hive failure'],
        ),
      );
      when(() => inspectionSynchronizer.syncInspections()).thenAnswer(
        (_) async => const InspectionSyncResult(
          totalPending: 4,
          syncedCount: 3,
          failedCount: 1,
          errors: ['inspection failure'],
        ),
      );

      final result = await dataSynchronizer.syncAll();

      expect(result.totalPending, 9);
      expect(result.syncedCount, 6);
      expect(result.failedCount, 3);
      expect(result.errors, [
        'apiary failure',
        'hive failure',
        'inspection failure',
      ]);
    },
  );
}
