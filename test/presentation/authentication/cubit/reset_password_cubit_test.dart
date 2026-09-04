import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:beebase/presentation/authentication/cubit/reset_password_cubit/reset_password_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPasswordResetFlow extends Mock implements IPasswordResetFlow {}

void main() {
  late MockPasswordResetFlow repository;

  setUp(() {
    repository = MockPasswordResetFlow();
  });

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'emits Loading then Success on a valid reset',
    build: () {
      when(
        () => repository.confirmPasswordReset(
          resetToken: any(named: 'resetToken'),
          newPassword: any(named: 'newPassword'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenAnswer((_) async => const Right(null));
      return ResetPasswordCubit(repository: repository);
    },
    act: (cubit) =>
        cubit.confirm(resetToken: 'reset-token', newPassword: 'new-password', confirmPassword: 'new-password'),
    expect: () => [const ResetPasswordLoading(), const ResetPasswordSuccess()],
  );

  blocTest<ResetPasswordCubit, ResetPasswordState>(
    'emits Loading then Error when the reset token has expired',
    build: () {
      when(
        () => repository.confirmPasswordReset(
          resetToken: any(named: 'resetToken'),
          newPassword: any(named: 'newPassword'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenAnswer(
        (_) async => Left(ServerFailure(code: 'password_reset_token_invalid', message: 'expired')),
      );
      return ResetPasswordCubit(repository: repository);
    },
    act: (cubit) =>
        cubit.confirm(resetToken: 'reset-token', newPassword: 'new-password', confirmPassword: 'new-password'),
    expect: () => [
      const ResetPasswordLoading(),
      ResetPasswordError(ServerFailure(code: 'password_reset_token_invalid', message: 'expired')),
    ],
  );
}
