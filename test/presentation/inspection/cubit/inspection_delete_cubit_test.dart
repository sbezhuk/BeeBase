import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_delete_cubit/inspection_delete_cubit.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionWriter extends Mock implements IInspectionWriter {}

void main() {
  late MockInspectionWriter writer;
  late InspectionListRefreshNotifier refreshNotifier;
  late bool notified;

  final inspection = Inspection(
    id: 'inspection-1',
    hiveId: 'hive-1',
    date: DateTime(2026),
    type: InspectionType.routine,
    notes: 'Test notes',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    writer = MockInspectionWriter();
    refreshNotifier = InspectionListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  blocTest<InspectionDeleteCubit, InspectionDeleteState>(
    'emits Loading then Success, deletes by hive+inspection id, and notifies the list',
    build: () {
      when(
        () => writer.deleteInspection(hiveId: 'hive-1', id: 'inspection-1'),
      ).thenAnswer((_) async => const Right(null));
      return InspectionDeleteCubit(
        writer: writer,
        inspection: inspection,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.delete(),
    expect: () => [const InspectionDeleteLoading(), const InspectionDeleteSuccess()],
    verify: (_) {
      verify(() => writer.deleteInspection(hiveId: 'hive-1', id: 'inspection-1')).called(1);
      expect(notified, isTrue);
    },
  );

  blocTest<InspectionDeleteCubit, InspectionDeleteState>(
    'emits Loading then Error on failure without notifying the list',
    build: () {
      when(
        () => writer.deleteInspection(hiveId: 'hive-1', id: 'inspection-1'),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'server_error', message: 'failed')));
      return InspectionDeleteCubit(
        writer: writer,
        inspection: inspection,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.delete(),
    expect: () => [
      const InspectionDeleteLoading(),
      InspectionDeleteError(ServerFailure(code: 'server_error', message: 'failed')),
    ],
    verify: (_) => expect(notified, isFalse),
  );
}
