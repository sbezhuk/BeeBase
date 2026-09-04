import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/password_reset_flow.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:beebase/presentation/authentication/cubit/forgot_password_email_cubit/forgot_password_email_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPasswordResetFlow extends Mock implements IPasswordResetFlow {}

void main() {
  late MockPasswordResetFlow repository;

  final flow = PasswordResetFlow(flowToken: 'flow-token', expiresAt: DateTime(2026));

  setUp(() {
    repository = MockPasswordResetFlow();
  });

  blocTest<ForgotPasswordEmailCubit, ForgotPasswordEmailState>(
    'emits Loading then Success carrying the flow',
    build: () {
      when(() => repository.requestPasswordReset(email: any(named: 'email'))).thenAnswer((_) async => Right(flow));
      return ForgotPasswordEmailCubit(repository: repository);
    },
    act: (cubit) => cubit.submit(email: 'bee@example.com'),
    expect: () => [const ForgotPasswordEmailLoading(), ForgotPasswordEmailSuccess(flow)],
  );

  blocTest<ForgotPasswordEmailCubit, ForgotPasswordEmailState>(
    'emits Loading then Error on a malformed email',
    build: () {
      when(() => repository.requestPasswordReset(email: any(named: 'email'))).thenAnswer(
        (_) async => Left(ServerFailure(code: 'validation_error', message: 'request validation failed')),
      );
      return ForgotPasswordEmailCubit(repository: repository);
    },
    act: (cubit) => cubit.submit(email: 'not-an-email'),
    expect: () => [
      const ForgotPasswordEmailLoading(),
      ForgotPasswordEmailError(ServerFailure(code: 'validation_error', message: 'request validation failed')),
    ],
  );
}
