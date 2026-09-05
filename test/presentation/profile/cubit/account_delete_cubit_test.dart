import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/domain/repositories/account_deleter.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/profile/cubit/account_delete_cubit/account_delete_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountDeleter extends Mock implements IAccountDeleter {}

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  late MockAccountDeleter deleter;
  late MockAuthenticationRepository repository;
  late AuthenticationCubit authenticationCubit;

  setUp(() {
    deleter = MockAccountDeleter();
    repository = MockAuthenticationRepository();
    when(() => repository.logout()).thenAnswer((_) async {});
    authenticationCubit = AuthenticationCubit(
      repository: repository,
      sessionService: SessionService(),
    );
  });

  tearDown(() {
    authenticationCubit.close();
  });

  blocTest<AccountDeleteCubit, AccountDeleteState>(
    'emits Loading then Success and hands off to AuthenticationCubit.logout()',
    build: () {
      when(
        () => deleter.deleteAccount(otp: any(named: 'otp')),
      ).thenAnswer((_) async => const Right(null));
      return AccountDeleteCubit(
        deleter: deleter,
        authenticationCubit: authenticationCubit,
      );
    },
    act: (cubit) => cubit.delete(otp: '123456'),
    expect: () => [const AccountDeleteLoading(), const AccountDeleteSuccess()],
    verify: (_) {
      verify(() => deleter.deleteAccount(otp: '123456')).called(1);
      verify(() => repository.logout()).called(1);
    },
  );

  blocTest<AccountDeleteCubit, AccountDeleteState>(
    'emits Loading then Error on failure, without clearing the session',
    build: () {
      when(() => deleter.deleteAccount(otp: any(named: 'otp'))).thenAnswer(
        (_) async =>
            Left(ServerFailure(code: 'server_error', message: 'failed')),
      );
      return AccountDeleteCubit(
        deleter: deleter,
        authenticationCubit: authenticationCubit,
      );
    },
    act: (cubit) => cubit.delete(otp: '000000'),
    expect: () => [
      const AccountDeleteLoading(),
      AccountDeleteError(
        ServerFailure(code: 'server_error', message: 'failed'),
      ),
    ],
    verify: (_) => verifyNever(() => repository.logout()),
  );
}
