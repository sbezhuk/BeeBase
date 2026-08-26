import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
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

  blocTest<RegisterCubit, RegisterState>(
    'emits Loading then Success and authenticates the app on a new account',
    build: () {
      when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(user));
      return RegisterCubit(
        repository: repository,
        authenticationCubit: authenticationCubit,
      );
    },
    act: (cubit) =>
        cubit.register(email: 'bee@example.com', password: 'password123'),
    expect: () => [const RegisterLoading(), RegisterSuccess(user)],
    verify: (_) =>
        verify(() => authenticationCubit.setAuthenticated(user)).called(1),
  );

  blocTest<RegisterCubit, RegisterState>(
    'emits Loading then Error when the email is already taken, without authenticating',
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
      return RegisterCubit(
        repository: repository,
        authenticationCubit: authenticationCubit,
      );
    },
    act: (cubit) =>
        cubit.register(email: 'bee@example.com', password: 'password123'),
    expect: () => [
      const RegisterLoading(),
      RegisterError(
        ServerFailure(code: 'email_taken', message: 'already registered'),
      ),
    ],
    verify: (_) =>
        verifyNever(() => authenticationCubit.setAuthenticated(any())),
  );
}
