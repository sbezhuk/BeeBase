import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_list_cubit/apiary_list_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryReader extends Mock implements IApiaryReader {}

void main() {
  late MockApiaryReader reader;
  late ApiaryListRefreshNotifier refreshNotifier;

  final apiary = Apiary(
    id: 'apiary-1',
    name: 'Back Garden',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    reader = MockApiaryReader();
    refreshNotifier = ApiaryListRefreshNotifier();
  });

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries emits Loading then Loaded on success',
    build: () {
      when(() => reader.getApiaries()).thenAnswer((_) async => Right([apiary]));
      return ApiaryListCubit(reader: reader, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListLoaded([apiary]),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'loadApiaries emits Loading then Error on failure',
    build: () {
      when(() => reader.getApiaries()).thenAnswer(
        (_) async =>
            Left(ServerFailure(code: 'server_error', message: 'failed')),
      );
      return ApiaryListCubit(reader: reader, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => cubit.loadApiaries(),
    expect: () => [
      const ApiaryListLoading(),
      ApiaryListError(ServerFailure(code: 'server_error', message: 'failed')),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'refresh emits Loaded without an intermediate Loading state',
    build: () {
      when(() => reader.getApiaries()).thenAnswer((_) async => Right([apiary]));
      return ApiaryListCubit(reader: reader, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      ApiaryListLoaded([apiary]),
    ],
  );

  blocTest<ApiaryListCubit, ApiaryListState>(
    'refreshes automatically when refreshNotifier signals a change',
    build: () {
      when(() => reader.getApiaries()).thenAnswer((_) async => Right([apiary]));
      return ApiaryListCubit(reader: reader, refreshNotifier: refreshNotifier);
    },
    act: (cubit) => refreshNotifier.notify(),
    expect: () => [
      ApiaryListLoaded([apiary]),
    ],
  );
}
