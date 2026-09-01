import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_form_cubit/inspection_form_cubit.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionWriter extends Mock implements IInspectionWriter {}

void main() {
  const hiveId = 'hive-1';
  final date = DateTime(2026, 1, 1);
  const type = InspectionType.queen;

  late MockInspectionWriter writer;
  late InspectionListRefreshNotifier refreshNotifier;
  late bool notified;

  final inspection = Inspection(
    id: 'inspection-1',
    hiveId: hiveId,
    date: date,
    type: type,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(InspectionType.routine);
  });

  setUp(() {
    writer = MockInspectionWriter();
    refreshNotifier = InspectionListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  group('create (no initial inspection)', () {
    blocTest<InspectionFormCubit, InspectionFormState>(
      'emits Loading then Success, calls createInspection with the hive id, and notifies the list',
      build: () {
        when(
          () => writer.createInspection(
            hiveId: hiveId,
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(inspection));
        return InspectionFormCubit(
          writer: writer,
          hiveId: hiveId,
          refreshNotifier: refreshNotifier,
        );
      },
      act: (cubit) => cubit.submit(date: date, type: type),
      expect: () => [const InspectionFormLoading(), InspectionFormSuccess(inspection)],
      verify: (_) {
        verify(
          () => writer.createInspection(hiveId: hiveId, date: date, type: type, notes: null),
        ).called(1);
        verifyNever(
          () => writer.updateInspection(
            hiveId: any(named: 'hiveId'),
            id: any(named: 'id'),
            date: any(named: 'date'),
            type: any(named: 'type'),
          ),
        );
        expect(notified, isTrue);
      },
    );

    blocTest<InspectionFormCubit, InspectionFormState>(
      'emits Loading then Error on failure without notifying the list',
      build: () {
        when(
          () => writer.createInspection(
            hiveId: hiveId,
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer(
          (_) async => Left(ServerFailure(code: 'validation_error', message: 'invalid')),
        );
        return InspectionFormCubit(
          writer: writer,
          hiveId: hiveId,
          refreshNotifier: refreshNotifier,
        );
      },
      act: (cubit) => cubit.submit(date: date, type: type),
      expect: () => [
        const InspectionFormLoading(),
        InspectionFormError(ServerFailure(code: 'validation_error', message: 'invalid')),
      ],
      verify: (_) => expect(notified, isFalse),
    );
  });

  group('update (with initial inspection)', () {
    blocTest<InspectionFormCubit, InspectionFormState>(
      'emits Loading then Success and calls updateInspection with the initial id',
      build: () {
        when(
          () => writer.updateInspection(
            hiveId: hiveId,
            id: any(named: 'id'),
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(inspection));
        return InspectionFormCubit(
          writer: writer,
          hiveId: hiveId,
          refreshNotifier: refreshNotifier,
          initial: inspection,
        );
      },
      act: (cubit) => cubit.submit(date: date, type: type, notes: 'Updated notes'),
      expect: () => [const InspectionFormLoading(), InspectionFormSuccess(inspection)],
      verify: (_) {
        verify(
          () => writer.updateInspection(
            hiveId: hiveId,
            id: 'inspection-1',
            date: date,
            type: type,
            notes: 'Updated notes',
          ),
        ).called(1);
        expect(notified, isTrue);
      },
    );
  });
}
