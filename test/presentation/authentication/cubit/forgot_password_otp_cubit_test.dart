import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/password_reset_verification.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:beebase/presentation/authentication/cubit/forgot_password_otp_cubit/forgot_password_otp_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPasswordResetFlow extends Mock implements IPasswordResetFlow {}

void main() {
  late MockPasswordResetFlow repository;

  final verification = PasswordResetVerification(resetToken: 'reset-token', expiresAt: DateTime(2026));

  setUp(() {
    repository = MockPasswordResetFlow();
  });

  blocTest<ForgotPasswordOtpCubit, ForgotPasswordOtpState>(
    'emits Loading then Success carrying the verification on a valid code',
    build: () {
      when(
        () => repository.verifyPasswordResetOtp(flowToken: any(named: 'flowToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => Right(verification));
      return ForgotPasswordOtpCubit(repository: repository);
    },
    act: (cubit) => cubit.verify(flowToken: 'flow-token', otp: '123456'),
    expect: () => [const ForgotPasswordOtpLoading(), ForgotPasswordOtpSuccess(verification)],
  );

  blocTest<ForgotPasswordOtpCubit, ForgotPasswordOtpState>(
    'emits Loading then Error on an invalid code',
    build: () {
      when(
        () => repository.verifyPasswordResetOtp(flowToken: any(named: 'flowToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'otp_invalid', message: 'wrong code')));
      return ForgotPasswordOtpCubit(repository: repository);
    },
    act: (cubit) => cubit.verify(flowToken: 'flow-token', otp: '000000'),
    expect: () => [
      const ForgotPasswordOtpLoading(),
      ForgotPasswordOtpError(ServerFailure(code: 'otp_invalid', message: 'wrong code')),
    ],
  );
}
