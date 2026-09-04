import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  late MockAuthenticationRepository repository;

  final challenge = TotpSetupChallenge(
    setupToken: 'setup-token',
    otpauthUri: 'otpauth://totp/BeeBase:bee@example.com?secret=JBSWY3DPEHPK3PXP&issuer=BeeBase',
    secret: 'JBSWY3DPEHPK3PXP',
    expiresAt: DateTime(2026),
  );

  setUp(() {
    repository = MockAuthenticationRepository();
  });

  blocTest<RegisterCubit, RegisterState>(
    'emits Loading then Success carrying the TOTP setup challenge on a new account',
    build: () {
      when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(challenge));
      return RegisterCubit(repository: repository);
    },
    act: (cubit) =>
        cubit.register(email: 'bee@example.com', password: 'password123'),
    expect: () => [const RegisterLoading(), RegisterSuccess(challenge)],
  );

  blocTest<RegisterCubit, RegisterState>(
    'emits Loading then Error when the email is already taken',
    build: () {
      when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => Left(
          ServerFailure(code: 'email_taken', message: 'already registered'),
        ),
      );
      return RegisterCubit(repository: repository);
    },
    act: (cubit) =>
        cubit.register(email: 'bee@example.com', password: 'password123'),
    expect: () => [
      const RegisterLoading(),
      RegisterError(
        ServerFailure(code: 'email_taken', message: 'already registered'),
      ),
    ],
  );
}
