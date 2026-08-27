import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_delete_cubit/apiary_delete_cubit.dart';
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

  blocTest<ApiaryDeleteCubit, ApiaryDeleteState>(
    'emits Loading then Success, deletes by the apiary id, and notifies the list',
    build: () {
      when(
        () => writer.deleteApiary('apiary-1'),
      ).thenAnswer((_) async => const Right(null));
      return ApiaryDeleteCubit(
        writer: writer,
        apiary: apiary,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.delete(),
    expect: () => [const ApiaryDeleteLoading(), const ApiaryDeleteSuccess()],
    verify: (_) {
      verify(() => writer.deleteApiary('apiary-1')).called(1);
      expect(notified, isTrue);
    },
  );

  blocTest<ApiaryDeleteCubit, ApiaryDeleteState>(
    'emits Loading then Error on failure without notifying the list',
    build: () {
      when(() => writer.deleteApiary('apiary-1')).thenAnswer(
        (_) async =>
            Left(ServerFailure(code: 'server_error', message: 'failed')),
      );
      return ApiaryDeleteCubit(
        writer: writer,
        apiary: apiary,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.delete(),
    expect: () => [
      const ApiaryDeleteLoading(),
      ApiaryDeleteError(ServerFailure(code: 'server_error', message: 'failed')),
    ],
    verify: (_) => expect(notified, isFalse),
  );
}
