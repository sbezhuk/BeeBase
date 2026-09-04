import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/totp_setup_cubit/totp_setup_cubit.dart';
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

  blocTest<TotpSetupCubit, TotpSetupState>(
    'emits Loading then Success and authenticates the app on a valid code',
    build: () {
      when(
        () => repository.verifyTotpSetup(setupToken: any(named: 'setupToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => Right(user));
      return TotpSetupCubit(repository: repository, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.verify(setupToken: 'setup-token', otp: '123456'),
    expect: () => [const TotpSetupLoading(), TotpSetupSuccess(user)],
    verify: (_) => verify(() => authenticationCubit.setAuthenticated(user)).called(1),
  );

  blocTest<TotpSetupCubit, TotpSetupState>(
    'emits Loading then Error on an invalid code, without authenticating',
    build: () {
      when(
        () => repository.verifyTotpSetup(setupToken: any(named: 'setupToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'otp_invalid', message: 'wrong code')));
      return TotpSetupCubit(repository: repository, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.verify(setupToken: 'setup-token', otp: '000000'),
    expect: () => [const TotpSetupLoading(), TotpSetupError(ServerFailure(code: 'otp_invalid', message: 'wrong code'))],
    verify: (_) => verifyNever(() => authenticationCubit.setAuthenticated(any())),
  );
}
