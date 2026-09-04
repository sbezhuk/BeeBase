import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/data/sync/data_synchronizer.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiarySynchronizer extends Mock implements IApiarySynchronizer {}

class MockHiveSynchronizer extends Mock implements IHiveSynchronizer {}

void main() {
  late MockApiarySynchronizer apiarySynchronizer;
  late MockHiveSynchronizer hiveSynchronizer;
  late DataSynchronizer dataSynchronizer;

  setUp(() {
    apiarySynchronizer = MockApiarySynchronizer();
    hiveSynchronizer = MockHiveSynchronizer();
    dataSynchronizer = DataSynchronizer(
      apiarySynchronizer: apiarySynchronizer,
      hiveSynchronizer: hiveSynchronizer,
    );
  });

  test('syncAll always synchronizes apiaries before hives', () async {
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

    final result = await dataSynchronizer.syncAll();

    expect(callOrder, ['apiaries', 'hives']);
    expect(result.isSuccess, isTrue);
    expect(result.syncedCount, 2);
  });

  test(
    'still runs hive sync (which will itself skip dependent hives) when apiary sync fails',
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

      final result = await dataSynchronizer.syncAll();

      verify(() => apiarySynchronizer.syncApiaries()).called(1);
      verify(() => hiveSynchronizer.syncHives()).called(1);
      expect(result.isSuccess, isFalse);
      expect(result.failedCount, 1);
      expect(result.hives.skippedCount, 1);
    },
  );

  test(
    'aggregates totals, failures and errors from both synchronizers',
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

      final result = await dataSynchronizer.syncAll();

      expect(result.totalPending, 5);
      expect(result.syncedCount, 3);
      expect(result.failedCount, 2);
      expect(result.errors, ['apiary failure', 'hive failure']);
    },
  );
}
