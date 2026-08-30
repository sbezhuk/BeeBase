import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/presentation/hive/cubit/hive_form_cubit/hive_form_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveWriter extends Mock implements IHiveWriter {}

void main() {
  const apiaryId = 'apiary-1';

  late MockHiveWriter writer;
  late HiveListRefreshNotifier refreshNotifier;
  late bool notified;

  final hive = Hive(
    id: 'hive-1',
    apiaryId: apiaryId,
    name: 'Hive 1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    writer = MockHiveWriter();
    refreshNotifier = HiveListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  group('create (no initial hive)', () {
    blocTest<HiveFormCubit, HiveFormState>(
      'emits Loading then Success, calls createHive with the apiary id, and notifies the list',
      build: () {
        when(
          () => writer.createHive(
            apiaryId: apiaryId,
            name: any(named: 'name'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(hive));
        return HiveFormCubit(
          writer: writer,
          apiaryId: apiaryId,
          refreshNotifier: refreshNotifier,
        );
      },
      act: (cubit) => cubit.submit(name: 'Hive 1'),
      expect: () => [const HiveFormLoading(), HiveFormSuccess(hive)],
      verify: (_) {
        verify(
          () => writer.createHive(
            apiaryId: apiaryId,
            name: 'Hive 1',
            notes: null,
          ),
        ).called(1);
        verifyNever(
          () => writer.updateHive(
            apiaryId: any(named: 'apiaryId'),
            id: any(named: 'id'),
            name: any(named: 'name'),
          ),
        );
        expect(notified, isTrue);
      },
    );

    blocTest<HiveFormCubit, HiveFormState>(
      'emits Loading then Error on failure without notifying the list',
      build: () {
        when(
          () => writer.createHive(
            apiaryId: apiaryId,
            name: any(named: 'name'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer(
          (_) async => Left(
            ServerFailure(code: 'name_required', message: 'name required'),
          ),
        );
        return HiveFormCubit(
          writer: writer,
          apiaryId: apiaryId,
          refreshNotifier: refreshNotifier,
        );
      },
      act: (cubit) => cubit.submit(name: ''),
      expect: () => [
        const HiveFormLoading(),
        HiveFormError(
          ServerFailure(code: 'name_required', message: 'name required'),
        ),
      ],
      verify: (_) => expect(notified, isFalse),
    );
  });

  group('update (with initial hive)', () {
    blocTest<HiveFormCubit, HiveFormState>(
      'emits Loading then Success and calls updateHive with the initial id',
      build: () {
        when(
          () => writer.updateHive(
            apiaryId: apiaryId,
            id: any(named: 'id'),
            name: any(named: 'name'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(hive));
        return HiveFormCubit(
          writer: writer,
          apiaryId: apiaryId,
          refreshNotifier: refreshNotifier,
          initial: hive,
        );
      },
      act: (cubit) => cubit.submit(name: 'Updated Name'),
      expect: () => [const HiveFormLoading(), HiveFormSuccess(hive)],
      verify: (_) {
        verify(
          () => writer.updateHive(
            apiaryId: apiaryId,
            id: 'hive-1',
            name: 'Updated Name',
            notes: null,
          ),
        ).called(1);
        expect(notified, isTrue);
      },
    );
  });
}
