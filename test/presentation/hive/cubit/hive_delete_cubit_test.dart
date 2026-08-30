import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/presentation/hive/cubit/hive_delete_cubit/hive_delete_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveWriter extends Mock implements IHiveWriter {}

void main() {
  late MockHiveWriter writer;
  late HiveListRefreshNotifier refreshNotifier;
  late bool notified;

  final hive = Hive(
    id: 'hive-1',
    apiaryId: 'apiary-1',
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

  blocTest<HiveDeleteCubit, HiveDeleteState>(
    'emits Loading then Success, deletes by the hive id, and notifies the list',
    build: () {
      when(
        () => writer.deleteHive('hive-1'),
      ).thenAnswer((_) async => const Right(null));
      return HiveDeleteCubit(
        writer: writer,
        hive: hive,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.delete(),
    expect: () => [const HiveDeleteLoading(), const HiveDeleteSuccess()],
    verify: (_) {
      verify(() => writer.deleteHive('hive-1')).called(1);
      expect(notified, isTrue);
    },
  );

  blocTest<HiveDeleteCubit, HiveDeleteState>(
    'emits Loading then Error on failure without notifying the list',
    build: () {
      when(() => writer.deleteHive('hive-1')).thenAnswer(
        (_) async =>
            Left(ServerFailure(code: 'server_error', message: 'failed')),
      );
      return HiveDeleteCubit(
        writer: writer,
        hive: hive,
        refreshNotifier: refreshNotifier,
      );
    },
    act: (cubit) => cubit.delete(),
    expect: () => [
      const HiveDeleteLoading(),
      HiveDeleteError(ServerFailure(code: 'server_error', message: 'failed')),
    ],
    verify: (_) => expect(notified, isFalse),
  );
}
