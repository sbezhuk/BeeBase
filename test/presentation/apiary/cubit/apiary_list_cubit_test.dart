import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_list_cubit/apiary_list_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryReader extends Mock implements IApiaryReader {}

class MockHiveReader extends Mock implements IHiveReader {}

void main() {
  late MockApiaryReader reader;
  late MockHiveReader hiveReader;
  late ApiaryListRefreshNotifier refreshNotifier;
  late HiveListRefreshNotifier hiveRefreshNotifier;

  final apiary = Apiary(id: 'apiary-1', name: 'Back Garden', createdAt: DateTime(2026), updatedAt: DateTime(2026));
  final apiaryPage2 = Apiary(id: 'apiary-2', name: 'Meadow', createdAt: DateTime(2026), updatedAt: DateTime(2026));

  ApiaryListCubit buildCubit() {
    return ApiaryListCubit(
      reader: reader,
      hiveReader: hiveReader,
      refreshNotifier: refreshNotifier,
      hiveRefreshNotifier: hiveRefreshNotifier,
    );
  }

  setUp(() {
    reader = MockApiaryReader();
    hiveReader = MockHiveReader();
    refreshNotifier = ApiaryListRefreshNotifier();
    hiveRefreshNotifier = HiveListRefreshNotifier();
    when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right(<String, int>{}));
  });

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries emits Loading then Loaded on success',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: false),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries emits Loading then Error on failure',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'server_error', message: 'failed')));
      return buildCubit();
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [const ApiaryListLoading(), ApiaryListError(ServerFailure(code: 'server_error', message: 'failed'))],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries emits an empty Loaded state for an empty first page',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const Right(Page(items: [], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [const ApiaryListLoading(), const ApiaryListLoaded([], page: 1, hasNext: false)],
    verify: (cubit) => expect((cubit.state as ApiaryListLoaded).isEmpty, isTrue),
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'refresh emits Loaded without an intermediate Loading state',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      ApiaryListLoaded([apiary], page: 1, hasNext: false),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'refreshes automatically when refreshNotifier signals a change',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) => refreshNotifier.notify(),
    expect: () => [
      ApiaryListLoaded([apiary], page: 1, hasNext: false),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadNextPage appends the next page and advances the page counter',
    build: () {
      when(
        () => reader.getApiaries(page: 1, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: true)));
      when(
        () => reader.getApiaries(page: 2, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary, apiaryPage2], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadApiaries();
      await cubit.loadNextPage();
    },
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: true),
      ApiaryListLoaded([apiary], page: 1, hasNext: true, isLoadingNextPage: true),
      ApiaryListLoaded([apiary, apiaryPage2], page: 2, hasNext: false),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadNextPage is a no-op once hasNext is false (last page)',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadApiaries();
      await cubit.loadNextPage();
    },
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: false),
    ],
    verify: (_) => verify(() => reader.getApiaries(page: 1, limit: any(named: 'limit'))).called(1),
  );

  final duplicateRequestCompleter = Completer<Either<Failure, Page<Apiary>>>();
  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadNextPage is a no-op while a page is already loading (duplicate-request prevention)',
    build: () {
      when(
        () => reader.getApiaries(page: 1, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: true)));
      when(() => reader.getApiaries(page: 2, limit: any(named: 'limit'))).thenAnswer((_) => duplicateRequestCompleter.future);
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadApiaries();
      unawaited(cubit.loadNextPage());
      await cubit.loadNextPage(); // second call while the first is still in flight
    },
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: true),
      ApiaryListLoaded([apiary], page: 1, hasNext: true, isLoadingNextPage: true),
    ],
    verify: (_) => verify(() => reader.getApiaries(page: 2, limit: any(named: 'limit'))).called(1),
    // Deliberately left uncompleted: the cubit closes before this in-flight
    // request would resolve, and completing it afterwards would try to emit
    // on a closed cubit. A bare unresolved Future (no Timer) doesn't trip
    // any test-framework leak detection, so leaving it pending is safe.
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadNextPage failure keeps the already-loaded items visible and records the failure',
    build: () {
      final failure = ServerFailure(code: 'server_error', message: 'failed');
      when(
        () => reader.getApiaries(page: 1, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: true)));
      when(() => reader.getApiaries(page: 2, limit: any(named: 'limit'))).thenAnswer((_) async => Left(failure));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadApiaries();
      await cubit.loadNextPage();
    },
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: true),
      ApiaryListLoaded([apiary], page: 1, hasNext: true, isLoadingNextPage: true),
      ApiaryListLoaded(
        [apiary],
        page: 1,
        hasNext: true,
        loadNextPageFailure: ServerFailure(code: 'server_error', message: 'failed'),
      ),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'retryLoadNextPage clears the failure and re-requests the same page',
    build: () {
      final failure = ServerFailure(code: 'server_error', message: 'failed');
      when(
        () => reader.getApiaries(page: 1, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: true)));
      var callCount = 0;
      when(() => reader.getApiaries(page: 2, limit: any(named: 'limit'))).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return Left(failure);
        return Right(Page(items: [apiary, apiaryPage2], hasNext: false));
      });
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadApiaries();
      await cubit.loadNextPage(); // fails
      await cubit.retryLoadNextPage(); // succeeds, still requesting page 2
    },
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: true),
      ApiaryListLoaded([apiary], page: 1, hasNext: true, isLoadingNextPage: true),
      ApiaryListLoaded(
        [apiary],
        page: 1,
        hasNext: true,
        loadNextPageFailure: ServerFailure(code: 'server_error', message: 'failed'),
      ),
      ApiaryListLoaded([apiary], page: 1, hasNext: true, isLoadingNextPage: true),
      ApiaryListLoaded([apiary, apiaryPage2], page: 2, hasNext: false),
    ],
    verify: (_) => verify(() => reader.getApiaries(page: 2, limit: any(named: 'limit'))).called(2),
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'refresh resets the page counter back to 1 from a later page',
    build: () {
      when(
        () => reader.getApiaries(page: 1, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: true)));
      when(
        () => reader.getApiaries(page: 2, limit: any(named: 'limit')),
      ).thenAnswer((_) async => Right(Page(items: [apiary, apiaryPage2], hasNext: false)));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.loadApiaries();
      await cubit.loadNextPage();
      await cubit.refresh();
    },
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: true),
      ApiaryListLoaded([apiary], page: 1, hasNext: true, isLoadingNextPage: true),
      ApiaryListLoaded([apiary, apiaryPage2], page: 2, hasNext: false),
      ApiaryListLoaded([apiary], page: 1, hasNext: true),
    ],
  );

  test('a stale load-more response is discarded once a concurrent refresh has already reset the list', () async {
    final refreshedApiary = Apiary(id: 'apiary-3', name: 'After Refresh', createdAt: DateTime(2026), updatedAt: DateTime(2026));
    final stalePageCompleter = Completer<Either<Failure, Page<Apiary>>>();
    var page1CallCount = 0;
    when(() => reader.getApiaries(page: 1, limit: any(named: 'limit'))).thenAnswer((_) async {
      page1CallCount++;
      // First call: the initial load. Second call: the refresh that races
      // the still-pending page-2 request below.
      return page1CallCount == 1
          ? Right(Page(items: [apiary], hasNext: true))
          : Right(Page(items: [refreshedApiary], hasNext: false));
    });
    when(() => reader.getApiaries(page: 2, limit: any(named: 'limit'))).thenAnswer((_) => stalePageCompleter.future);

    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.loadApiaries();
    final loadMoreFuture = cubit.loadNextPage();
    await cubit.refresh();

    // The stale page-2 response now lands — it must be discarded, not appended
    // onto the freshly refreshed list.
    stalePageCompleter.complete(Right(Page(items: [apiary, apiaryPage2], hasNext: false)));
    await loadMoreFuture;

    expect(cubit.state, ApiaryListLoaded([refreshedApiary], page: 1, hasNext: false));
  });

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries emits the real hive counts fetched alongside the apiary page',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right({'apiary-1': 3}));
      return buildCubit();
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: false, hiveCounts: const {'apiary-1': 3}),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries degrades to an empty hive-count map when the count fetch fails, without failing the whole list',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      when(
        () => hiveReader.getHiveCounts(),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'server_error', message: 'failed')));
      return buildCubit();
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary], page: 1, hasNext: false),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'refreshes automatically when hiveRefreshNotifier signals a change',
    build: () {
      when(
        () => reader.getApiaries(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [apiary], hasNext: false)));
      when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right({'apiary-1': 1}));
      return buildCubit();
    },
    act: (cubit) => hiveRefreshNotifier.notify(),
    expect: () => [
      ApiaryListLoaded([apiary], page: 1, hasNext: false, hiveCounts: const {'apiary-1': 1}),
    ],
  );
}
