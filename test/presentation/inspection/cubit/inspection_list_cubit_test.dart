import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_list_cubit/inspection_list_cubit.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionReader extends Mock implements IInspectionReader {}

void main() {
  const hiveId = 'hive-1';

  late MockInspectionReader reader;
  late InspectionListRefreshNotifier refreshNotifier;

  final inspection = Inspection(
    id: 'inspection-1',
    hiveId: hiveId,
    date: DateTime(2026),
    type: InspectionType.routine,
    notes: 'Test notes',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final inspectionPage2 = Inspection(
    id: 'inspection-2',
    hiveId: hiveId,
    date: DateTime(2026),
    type: InspectionType.routine,
    notes: 'Test notes',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    reader = MockInspectionReader();
    refreshNotifier = InspectionListRefreshNotifier();
  });

  blocTest<InspectionListCubit, InspectionListState>(
    'loadInspections emits Loading then Loaded on success, scoped to this hive',
    build: () {
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection], hasNext: false)));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => cubit.loadInspections(),
    expect: () => [
      const InspectionListLoading(),
      InspectionListLoaded([inspection], page: 1, hasNext: false),
    ],
  );

  blocTest<InspectionListCubit, InspectionListState>(
    'loadInspections emits Loading then Error on failure',
    build: () {
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'server_error', message: 'failed')));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => cubit.loadInspections(),
    expect: () => [
      const InspectionListLoading(),
      InspectionListError(ServerFailure(code: 'server_error', message: 'failed')),
    ],
  );

  blocTest<InspectionListCubit, InspectionListState>(
    'refresh emits Loaded without an intermediate Loading state',
    build: () {
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection], hasNext: false)));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      InspectionListLoaded([inspection], page: 1, hasNext: false),
    ],
  );

  blocTest<InspectionListCubit, InspectionListState>(
    'refreshes automatically when refreshNotifier signals a change',
    build: () {
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection], hasNext: false)));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => refreshNotifier.notify(),
    expect: () => [
      InspectionListLoaded([inspection], page: 1, hasNext: false),
    ],
  );

  blocTest<InspectionListCubit, InspectionListState>(
    'loadNextPage appends the next page and advances the page counter',
    build: () {
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection], hasNext: true)));
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: 2,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection, inspectionPage2], hasNext: false)));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) async {
      await cubit.loadInspections();
      await cubit.loadNextPage();
    },
    expect: () => [
      const InspectionListLoading(),
      InspectionListLoaded([inspection], page: 1, hasNext: true),
      InspectionListLoaded([inspection], page: 1, hasNext: true, isLoadingNextPage: true),
      InspectionListLoaded([inspection, inspectionPage2], page: 2, hasNext: false),
    ],
  );

  blocTest<InspectionListCubit, InspectionListState>(
    'loadNextPage is a no-op once hasNext is false (last page)',
    build: () {
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection], hasNext: false)));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) async {
      await cubit.loadInspections();
      await cubit.loadNextPage();
    },
    expect: () => [
      const InspectionListLoading(),
      InspectionListLoaded([inspection], page: 1, hasNext: false),
    ],
    verify: (_) => verify(
      () => reader.getInspections(
        hiveId: hiveId,
        page: 1,
        limit: any(named: 'limit'),
      ),
    ).called(1),
  );

  blocTest<InspectionListCubit, InspectionListState>(
    'loadNextPage failure keeps the already-loaded items visible and records the failure',
    build: () {
      final failure = ServerFailure(code: 'server_error', message: 'failed');
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: 1,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Right(Page(items: [inspection], hasNext: true)));
      when(
        () => reader.getInspections(
          hiveId: hiveId,
          page: 2,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => Left(failure));
      return InspectionListCubit(reader: reader, hiveId: hiveId, refreshNotifier: refreshNotifier);
    },
    act: (cubit) async {
      await cubit.loadInspections();
      await cubit.loadNextPage();
    },
    expect: () => [
      const InspectionListLoading(),
      InspectionListLoaded([inspection], page: 1, hasNext: true),
      InspectionListLoaded([inspection], page: 1, hasNext: true, isLoadingNextPage: true),
      InspectionListLoaded(
        [inspection],
        page: 1,
        hasNext: true,
        loadNextPageFailure: ServerFailure(code: 'server_error', message: 'failed'),
      ),
    ],
  );
}
