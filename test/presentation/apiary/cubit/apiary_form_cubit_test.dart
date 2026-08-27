import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_form_cubit/apiary_form_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryWriter extends Mock implements IApiaryWriter {}

void main() {
  late MockApiaryWriter writer;
  late ApiaryListRefreshNotifier refreshNotifier;
  late bool notified;

  final apiary = Apiary(
    id: 'apiary-1',
    name: 'Back Garden',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    writer = MockApiaryWriter();
    refreshNotifier = ApiaryListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  group('create (no initial apiary)', () {
    blocTest<ApiaryFormCubit, ApiaryFormState>(
      'emits Loading then Success, calls createApiary, and notifies the list',
      build: () {
        when(
          () => writer.createApiary(
            name: any(named: 'name'),
            description: any(named: 'description'),
            location: any(named: 'location'),
          ),
        ).thenAnswer((_) async => Right(apiary));
        return ApiaryFormCubit(
          writer: writer,
          refreshNotifier: refreshNotifier,
        );
      },
      act: (cubit) => cubit.submit(name: 'Back Garden'),
      expect: () => [const ApiaryFormLoading(), ApiaryFormSuccess(apiary)],
      verify: (_) {
        verify(
          () => writer.createApiary(
            name: 'Back Garden',
            description: null,
            location: null,
          ),
        ).called(1);
        verifyNever(
          () => writer.updateApiary(
            id: any(named: 'id'),
            name: any(named: 'name'),
          ),
        );
        expect(notified, isTrue);
      },
    );

    blocTest<ApiaryFormCubit, ApiaryFormState>(
      'emits Loading then Error on failure without notifying the list',
      build: () {
        when(
          () => writer.createApiary(
            name: any(named: 'name'),
            description: any(named: 'description'),
            location: any(named: 'location'),
          ),
        ).thenAnswer(
          (_) async => Left(
            ServerFailure(code: 'name_required', message: 'name required'),
          ),
        );
        return ApiaryFormCubit(
          writer: writer,
          refreshNotifier: refreshNotifier,
        );
      },
      act: (cubit) => cubit.submit(name: ''),
      expect: () => [
        const ApiaryFormLoading(),
        ApiaryFormError(
          ServerFailure(code: 'name_required', message: 'name required'),
        ),
      ],
      verify: (_) => expect(notified, isFalse),
    );
  });

  group('update (with initial apiary)', () {
    blocTest<ApiaryFormCubit, ApiaryFormState>(
      'emits Loading then Success and calls updateApiary with the initial id',
      build: () {
        when(
          () => writer.updateApiary(
            id: any(named: 'id'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            location: any(named: 'location'),
          ),
        ).thenAnswer((_) async => Right(apiary));
        return ApiaryFormCubit(
          writer: writer,
          refreshNotifier: refreshNotifier,
          initial: apiary,
        );
      },
      act: (cubit) => cubit.submit(name: 'Updated Name'),
      expect: () => [const ApiaryFormLoading(), ApiaryFormSuccess(apiary)],
      verify: (_) {
        verify(
          () => writer.updateApiary(
            id: 'apiary-1',
            name: 'Updated Name',
            description: null,
            location: null,
          ),
        ).called(1);
        expect(notified, isTrue);
      },
    );
  });
}
