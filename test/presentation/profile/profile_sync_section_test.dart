import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/profile/profile_page.dart';
import 'package:beebase/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryLocalDataSource extends Mock implements IApiaryLocalDataSource {}

class MockApiarySynchronizer extends Mock implements IApiarySynchronizer {}

void main() {
  late MockApiaryLocalDataSource localDataSource;
  late MockApiarySynchronizer synchronizer;

  setUp(() {
    localDataSource = MockApiaryLocalDataSource();
    synchronizer = MockApiarySynchronizer();

    di.registerLazySingleton<IApiaryLocalDataSource>(() => localDataSource);
    di.registerLazySingleton<IApiarySynchronizer>(() => synchronizer);
  });

  tearDown(di.reset);

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileSyncSection(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders sync section title and sync button', (tester) async {
    when(() => localDataSource.getPendingSyncApiaries())
        .thenAnswer((_) async => []);

    await pumpSection(tester);

    expect(find.byType(ProfileSyncSection), findsOneWidget);
    expect(find.text('PROFILE.PAGE.SYNC_SECTION'), findsOneWidget);
    expect(find.text('profile.page.sync_data'), findsOneWidget);
    expect(find.text('profile.page.sync_now'), findsOneWidget);
  });

  testWidgets('shows pending items count when changes are pending', (tester) async {
    final pendingApiary = Apiary(
      id: 'local-1',
      localId: 'local-1',
      name: 'Test Apiary',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      syncStatus: SyncStatus.pendingCreate,
    );

    when(() => localDataSource.getPendingSyncApiaries())
        .thenAnswer((_) async => [pendingApiary]);

    await pumpSection(tester);

    expect(find.text('profile.page.sync_pending_count'), findsOneWidget);
  });

  testWidgets('tapping sync invokes syncApiaries on synchronizer', (tester) async {
    when(() => localDataSource.getPendingSyncApiaries())
        .thenAnswer((_) async => []);
    when(() => synchronizer.syncApiaries()).thenAnswer(
      (_) async => const ApiarySyncResult(
        totalPending: 0,
        syncedCount: 0,
        failedCount: 0,
      ),
    );

    await pumpSection(tester);

    await tester.tap(find.text('profile.page.sync_now'));
    await tester.pump();

    verify(() => synchronizer.syncApiaries()).called(1);
  });
}
