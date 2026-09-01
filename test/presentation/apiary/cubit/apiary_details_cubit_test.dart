import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_details_cubit/apiary_details_cubit.dart';
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

  setUp(() {
    reader = MockApiaryReader();
    refreshNotifier = ApiaryListRefreshNotifier();
  });

  test('starts with the Apiary it was seeded with, without reading anything', () {
    final cubit = ApiaryDetailsCubit(apiary: apiary, reader: reader, refreshNotifier: refreshNotifier);
    addTearDown(cubit.close);

    expect(cubit.state.apiary, apiary);
    verifyZeroInteractions(reader);
  });

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'picks up a re-resolved address once the refresh notifier fires after a background sync',
    build: () {
      when(() => reader.getCachedApiary('apiary-1')).thenAnswer((_) async => resolved);
      return ApiaryDetailsCubit(apiary: apiary, reader: reader, refreshNotifier: refreshNotifier);
    },
    act: (_) => refreshNotifier.notify(),
    expect: () => [ApiaryDetailsLoaded(resolved)],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'keeps the current state when the cache no longer has this id (nothing to refresh from)',
    build: () {
      when(() => reader.getCachedApiary('apiary-1')).thenAnswer((_) async => null);
      return ApiaryDetailsCubit(apiary: apiary, reader: reader, refreshNotifier: refreshNotifier);
    },
    act: (_) => refreshNotifier.notify(),
    expect: () => <ApiaryDetailsState>[],
  );

  blocTest<ApiaryDetailsCubit, ApiaryDetailsState>(
    'setApiary applies an edited Apiary immediately, without waiting for the refresh signal',
    build: () => ApiaryDetailsCubit(apiary: apiary, reader: reader, refreshNotifier: refreshNotifier),
    act: (cubit) => cubit.setApiary(resolved),
    expect: () => [ApiaryDetailsLoaded(resolved)],
    verify: (_) => verifyNever(() => reader.getCachedApiary(any())),
  );

  test('stops listening to the refresh notifier once closed', () async {
    when(() => reader.getCachedApiary('apiary-1')).thenAnswer((_) async => resolved);
    final cubit = ApiaryDetailsCubit(apiary: apiary, reader: reader, refreshNotifier: refreshNotifier);

    await cubit.close();
    refreshNotifier.notify();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.apiary, apiary);
  });
}
