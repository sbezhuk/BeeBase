import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/repositories/password_changer.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/profile/cubit/change_password_cubit/change_password_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPasswordChanger extends Mock implements IPasswordChanger {}

class MockAuthenticationCubit extends MockCubit<AuthenticationState> implements AuthenticationCubit {}

void main() {
  late MockPasswordChanger repository;
  late MockAuthenticationCubit authenticationCubit;

  setUp(() {
    repository = MockPasswordChanger();
    authenticationCubit = MockAuthenticationCubit();
    when(() => authenticationCubit.logout()).thenAnswer((_) async {});
  });

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits Loading then Success and logs the app out on a valid change',
    build: () {
      when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer((_) async => const Right(null));
      return ChangePasswordCubit(repository: repository, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(currentPassword: 'old-password', newPassword: 'new-password', otp: '123456'),
    expect: () => [const ChangePasswordLoading(), const ChangePasswordSuccess()],
    verify: (_) => verify(() => authenticationCubit.logout()).called(1),
  );

  blocTest<ChangePasswordCubit, ChangePasswordState>(
    'emits Loading then Error on the wrong current password, without logging out',
    build: () {
      when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer(
        (_) async => Left(ServerFailure(code: 'current_password_invalid', message: 'wrong password')),
      );
      return ChangePasswordCubit(repository: repository, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(currentPassword: 'wrong-password', newPassword: 'new-password', otp: '123456'),
    expect: () => [
      const ChangePasswordLoading(),
      ChangePasswordError(ServerFailure(code: 'current_password_invalid', message: 'wrong password')),
    ],
    verify: (_) => verifyNever(() => authenticationCubit.logout()),
  );
}
