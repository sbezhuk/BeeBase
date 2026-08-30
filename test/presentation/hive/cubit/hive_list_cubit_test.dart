import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/presentation/hive/cubit/hive_list_cubit/hive_list_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveReader extends Mock implements IHiveReader {}

void main() {
  const apiaryId = 'apiary-1';

  late MockHiveReader reader;
  late HiveListRefreshNotifier refreshNotifier;

  final hive = Hive(
    id: 'hive-1',
    apiaryId: apiaryId,
    name: 'Hive 1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final hivePage2 = Hive(
    id: 'hive-2',
    apiaryId: apiaryId,
    name: 'Hive 2',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    reader = MockHiveReader();
    refreshNotifier = HiveListRefreshNotifier();
  });

  blocTest<HiveListCubit, HiveListState>(
    'loadHives emits Loading then Loaded on success, scoped to this apiary',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: false)));
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.loadHives(),
    expect: () => [
      const HiveListLoading(),
      HiveListLoaded([hive], page: 1, hasNext: false),
    ],
  );

  blocTest<HiveListCubit, HiveListState>(
    'loadHives emits Loading then Error on failure',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            Left(ServerFailure(code: 'server_error', message: 'failed')),
      );
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.loadHives(),
    expect: () => [
      const HiveListLoading(),
      HiveListError(ServerFailure(code: 'server_error', message: 'failed')),
    ],
  );

  blocTest<HiveListCubit, HiveListState>(
    'refresh emits Loaded without an intermediate Loading state',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: false)));
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      HiveListLoaded([hive], page: 1, hasNext: false),
    ],
  );

  blocTest<HiveListCubit, HiveListState>(
    'refreshes automatically when refreshNotifier signals a change',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: false)));
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => refreshNotifier.notify(),
    expect: () => [
      HiveListLoaded([hive], page: 1, hasNext: false),
    ],
  );

  blocTest<HiveListCubit, HiveListState>(
    'loadNextPage appends the next page and advances the page counter',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: true)));
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: 2,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => Right(Page(items: [hive, hivePage2], hasNext: false)),
      );
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) async {
      await cubit.loadHives();
      await cubit.loadNextPage();
    },
    expect: () => [
      const HiveListLoading(),
      HiveListLoaded([hive], page: 1, hasNext: true),
      HiveListLoaded([hive], page: 1, hasNext: true, isLoadingNextPage: true),
      HiveListLoaded([hive, hivePage2], page: 2, hasNext: false),
    ],
  );

  blocTest<HiveListCubit, HiveListState>(
    'loadNextPage is a no-op once hasNext is false (last page)',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: false)));
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) async {
      await cubit.loadHives();
      await cubit.loadNextPage();
    },
    expect: () => [
      const HiveListLoading(),
      HiveListLoaded([hive], page: 1, hasNext: false),
    ],
    verify: (_) => verify(
      () => reader.getHives(
        apiaryId: apiaryId,
        page: 1,
        limit: any(named: 'limit'),
      ),
    ).called(1),
  );

  blocTest<HiveListCubit, HiveListState>(
    'loadNextPage failure keeps the already-loaded items visible and records the failure',
    build: () {
      final failure = ServerFailure(code: 'server_error', message: 'failed');
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: true)));
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: 2,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Left(failure));
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) async {
      await cubit.loadHives();
      await cubit.loadNextPage();
    },
    expect: () => [
      const HiveListLoading(),
      HiveListLoaded([hive], page: 1, hasNext: true),
      HiveListLoaded([hive], page: 1, hasNext: true, isLoadingNextPage: true),
      HiveListLoaded(
        [hive],
        page: 1,
        hasNext: true,
        loadNextPageFailure: ServerFailure(
          code: 'server_error',
          message: 'failed',
        ),
      ),
    ],
  );

  final duplicateRequestCompleter = Completer<Either<Failure, Page<Hive>>>();
  blocTest<HiveListCubit, HiveListState>(
    'loadNextPage is a no-op while a page is already loading (duplicate-request prevention)',
    build: () {
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [hive], hasNext: true)));
      when(
        () => reader.getHives(
          apiaryId: apiaryId,
          page: 2,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => duplicateRequestCompleter.future);
      return HiveListCubit(
        reader: reader,
        apiaryId: apiaryId,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) async {
      await cubit.loadHives();
      unawaited(cubit.loadNextPage());
      await cubit.loadNextPage();
    },
    expect: () => [
      const HiveListLoading(),
      HiveListLoaded([hive], page: 1, hasNext: true),
      HiveListLoaded([hive], page: 1, hasNext: true, isLoadingNextPage: true),
    ],
    verify: (_) => verify(
      () => reader.getHives(
        apiaryId: apiaryId,
        page: 2,
        limit: any(named: 'limit'),
      ),
    ).called(1),
  );
}
