import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  late MockAuthenticationRepository repository;

  final challenge = LoginOtpChallenge(challengeToken: 'challenge-token', expiresAt: DateTime(2026));

  setUp(() {
    repository = MockAuthenticationRepository();
  });

  blocTest<LoginCubit, LoginState>(
    'emits Loading then Success carrying the challenge on valid credentials',
    build: () {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(challenge));
      return LoginCubit(repository: repository);
    },
    act: (cubit) =>
        cubit.login(email: 'bee@example.com', password: 'password123'),
    expect: () => [const LoginLoading(), LoginSuccess(challenge)],
  );

  blocTest<LoginCubit, LoginState>(
    'emits Loading then Error on invalid credentials',
    build: () {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => Left(
          ServerFailure(
            code: 'invalid_credentials',
            message: 'invalid email or password',
          ),
        ),
      );
      return LoginCubit(repository: repository);
    },
    act: (cubit) => cubit.login(email: 'bee@example.com', password: 'wrong'),
    expect: () => [
      const LoginLoading(),
      LoginError(
        ServerFailure(
          code: 'invalid_credentials',
          message: 'invalid email or password',
        ),
      ),
    ],
  );
}
