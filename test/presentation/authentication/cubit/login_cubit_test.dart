import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class MockAuthenticationCubit extends MockCubit<AuthenticationState>
    implements AuthenticationCubit {}

void main() {
  late MockAuthenticationRepository repository;
  late MockAuthenticationCubit authenticationCubit;

  final user = User(
    id: 'user-1',
    email: 'bee@example.com',
    createdAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(user);
  });

  setUp(() {
    repository = MockAuthenticationRepository();
    authenticationCubit = MockAuthenticationCubit();
  });

  blocTest<LoginCubit, LoginState>(
    'emits Loading then Success and authenticates the app on valid credentials',
    build: () {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(user));
      return LoginCubit(
        repository: repository,
        authenticationCubit: authenticationCubit,
      );
    },
    act: (cubit) =>
        cubit.login(email: 'bee@example.com', password: 'password123'),
    expect: () => [const LoginLoading(), LoginSuccess(user)],
    verify: (_) =>
        verify(() => authenticationCubit.setAuthenticated(user)).called(1),
  );

  blocTest<LoginCubit, LoginState>(
    'emits Loading then Error on invalid credentials, without authenticating',
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
      return LoginCubit(
        repository: repository,
        authenticationCubit: authenticationCubit,
      );
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
    verify: (_) =>
        verifyNever(() => authenticationCubit.setAuthenticated(any())),
  );
}
