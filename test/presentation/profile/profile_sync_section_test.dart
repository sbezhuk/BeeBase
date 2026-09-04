import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/data/sync/data_synchronizer.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/profile/profile_page.dart';
import 'package:beebase/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryLocalDataSource extends Mock
    implements IApiaryLocalDataSource {}

class MockHiveLocalDataSource extends Mock implements IHiveLocalDataSource {}

class MockDataSynchronizer extends Mock implements IDataSynchronizer {}

void main() {
  late MockApiaryLocalDataSource apiaryLocalDataSource;
  late MockHiveLocalDataSource hiveLocalDataSource;
  late MockDataSynchronizer synchronizer;

  setUp(() {
    apiaryLocalDataSource = MockApiaryLocalDataSource();
    hiveLocalDataSource = MockHiveLocalDataSource();
    synchronizer = MockDataSynchronizer();

    di.registerLazySingleton<IApiaryLocalDataSource>(
      () => apiaryLocalDataSource,
    );
    di.registerLazySingleton<IHiveLocalDataSource>(() => hiveLocalDataSource);
    di.registerLazySingleton<IDataSynchronizer>(() => synchronizer);

    when(
      () => hiveLocalDataSource.getPendingSyncHives(),
    ).thenAnswer((_) async => []);
  });

  tearDown(di.reset);

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileSyncSection())),
    );
    await tester.pump();
  }

  testWidgets('renders sync section title and sync button', (tester) async {
    when(
      () => apiaryLocalDataSource.getPendingSyncApiaries(),
    ).thenAnswer((_) async => []);

    await pumpSection(tester);

    expect(find.byType(ProfileSyncSection), findsOneWidget);
    expect(find.text('PROFILE.PAGE.SYNC_SECTION'), findsOneWidget);
    expect(find.text('profile.page.sync_data'), findsOneWidget);
    expect(find.text('profile.page.sync_now'), findsOneWidget);
  });

  testWidgets('shows pending items count when changes are pending', (
    tester,
  ) async {
    final pendingApiary = Apiary(
      id: 'local-1',
      localId: 'local-1',
      name: 'Test Apiary',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      syncStatus: SyncStatus.pendingCreate,
    );

    when(
      () => apiaryLocalDataSource.getPendingSyncApiaries(),
    ).thenAnswer((_) async => [pendingApiary]);

    await pumpSection(tester);

    expect(find.text('profile.page.sync_pending_count'), findsOneWidget);
  });

  testWidgets('tapping sync invokes syncAll on the data synchronizer', (
    tester,
  ) async {
    when(
      () => apiaryLocalDataSource.getPendingSyncApiaries(),
    ).thenAnswer((_) async => []);
    when(() => synchronizer.syncAll()).thenAnswer(
      (_) async => const DataSyncResult(
        apiaries: ApiarySyncResult(
          totalPending: 0,
          syncedCount: 0,
          failedCount: 0,
        ),
        hives: HiveSyncResult(totalPending: 0, syncedCount: 0, failedCount: 0),
      ),
    );

    await pumpSection(tester);

    await tester.tap(find.text('profile.page.sync_now'));
    await tester.pump();

    verify(() => synchronizer.syncAll()).called(1);
  });
}
