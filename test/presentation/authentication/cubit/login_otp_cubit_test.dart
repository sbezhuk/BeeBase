import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/login_otp_cubit/login_otp_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock implements AuthenticationRepository {}

class MockAuthenticationCubit extends MockCubit<AuthenticationState> implements AuthenticationCubit {}

void main() {
  late MockAuthenticationRepository repository;
  late MockAuthenticationCubit authenticationCubit;

  final user = User(id: 'user-1', email: 'bee@example.com', createdAt: DateTime(2026));

  setUpAll(() {
    registerFallbackValue(user);
  });

  setUp(() {
    repository = MockAuthenticationRepository();
    authenticationCubit = MockAuthenticationCubit();
  });

  blocTest<LoginOtpCubit, LoginOtpState>(
    'emits Loading then Success and authenticates the app on a valid code',
    build: () {
      when(
        () => repository.verifyLoginOtp(challengeToken: any(named: 'challengeToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => Right(user));
      return LoginOtpCubit(repository: repository, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.verify(challengeToken: 'challenge-token', otp: '123456'),
    expect: () => [const LoginOtpLoading(), LoginOtpSuccess(user)],
    verify: (_) => verify(() => authenticationCubit.setAuthenticated(user)).called(1),
  );

  blocTest<LoginOtpCubit, LoginOtpState>(
    'emits Loading then Error when the attempt cap is hit, without authenticating',
    build: () {
      when(
        () => repository.verifyLoginOtp(challengeToken: any(named: 'challengeToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'otp_locked', message: 'too many attempts')));
      return LoginOtpCubit(repository: repository, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.verify(challengeToken: 'challenge-token', otp: '000000'),
    expect: () => [
      const LoginOtpLoading(),
      LoginOtpError(ServerFailure(code: 'otp_locked', message: 'too many attempts')),
    ],
    verify: (_) => verifyNever(() => authenticationCubit.setAuthenticated(any())),
  );
}
