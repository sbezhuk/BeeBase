import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_details_cubit/apiary_details_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
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

  final apiary = Apiary(
    id: 'apiary-1',
    name: 'Back Garden',
    location: 'Current location (address unavailable while offline)',
    lat: 40,
    lon: -74,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final resolved = Apiary(
    id: 'apiary-1',
    name: 'Back Garden',
    location: 'Main St, Springfield',
    lat: 40,
    lon: -74,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  ApiaryDetailsCubit buildCubit({Apiary? seed}) {
    return ApiaryDetailsCubit(
      apiary: seed ?? apiary,
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
  });

  test('starts with the Apiary it was seeded with, without reading anything', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state.apiary, apiary);
    verifyZeroInteractions(reader);
    verifyZeroInteractions(hiveReader);
  });

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'picks up refreshed apiary once the refresh notifier fires',
    build: () {
      when(() => reader.getApiary('apiary-1')).thenAnswer((_) async => Right(resolved));
      return buildCubit();
    },
    act: (_) => refreshNotifier.notify(),
    expect: () => [ApiaryDetailsLoaded(resolved)],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'keeps the current state when getApiary fails',
    build: () {
      when(
        () => reader.getApiary('apiary-1'),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'server_error', message: 'failed')));
      return buildCubit();
    },
    act: (_) => refreshNotifier.notify(),
    expect: () => <ApiaryDetailsState>[],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'setApiary applies an edited Apiary immediately, without waiting for the refresh signal',
    build: buildCubit,
    act: (cubit) => cubit.setApiary(resolved),
    expect: () => [ApiaryDetailsLoaded(resolved)],
    verify: (_) => verifyNever(() => reader.getApiary(any())),
  );

  test('stops listening to the refresh notifier once closed', () async {
    when(() => reader.getApiary('apiary-1')).thenAnswer((_) async => Right(resolved));
    final cubit = buildCubit();

    await cubit.close();
    refreshNotifier.notify();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.apiary, apiary);
  });

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'loadHiveCount emits the real hive count for this apiary',
    build: () {
      when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right({'apiary-1': 4}));
      return buildCubit();
    },
    act: (cubit) => cubit.loadHiveCount(),
    expect: () => [ApiaryDetailsLoaded(apiary, hiveCount: 4)],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'loadHiveCount emits zero when this apiary has no hives, rather than leaving the count unset',
    build: () {
      when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right({}));
      return buildCubit();
    },
    act: (cubit) => cubit.loadHiveCount(),
    expect: () => [ApiaryDetailsLoaded(apiary, hiveCount: 0)],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'loadHiveCount leaves the state untouched when the fetch fails',
    build: () {
      when(
        () => hiveReader.getHiveCounts(),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'server_error', message: 'failed')));
      return buildCubit();
    },
    act: (cubit) => cubit.loadHiveCount(),
    expect: () => <ApiaryDetailsState>[],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'refreshes the hive count automatically when hiveRefreshNotifier signals a change, e.g. after adding a hive',
    build: () {
      when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right({'apiary-1': 1}));
      return buildCubit();
    },
    act: (_) => hiveRefreshNotifier.notify(),
    expect: () => [ApiaryDetailsLoaded(apiary, hiveCount: 1)],
  );

  test('stops listening to the hive refresh notifier once closed', () async {
    when(() => hiveReader.getHiveCounts()).thenAnswer((_) async => const Right({'apiary-1': 1}));
    final cubit = buildCubit();

    await cubit.close();
    hiveRefreshNotifier.notify();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.hiveCount, isNull);
  });
}
