import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  late MockAuthenticationRepository repository;
  late SessionService sessionService;

  final user = User(
    id: 'user-1',
    email: 'bee@example.com',
    createdAt: DateTime(2026),
  );

  setUp(() {
    repository = MockAuthenticationRepository();
    sessionService = SessionService();
  });

  blocTest<AuthenticationCubit, AuthenticationState>(
    'starts as AuthenticationUnknown',
    build: () => AuthenticationCubit(
      repository: repository,
      sessionService: sessionService,
    ),
    verify: (cubit) => expect(cubit.state, isA<AuthenticationUnknown>()),
  );

  blocTest<AuthenticationCubit, AuthenticationState>(
    'restoreSession emits Authenticated when the repository resolves a user',
    build: () {
      when(
        () => repository.restoreSession(),
      ).thenAnswer((_) async => Right(user));
      return AuthenticationCubit(
        repository: repository,
        sessionService: sessionService,
      );
    },
    act: (cubit) => cubit.restoreSession(),
    expect: () => [AuthenticationAuthenticated(user)],
  );

  blocTest<AuthenticationCubit, AuthenticationState>(
    'restoreSession emits Unauthenticated when there is no valid session',
    build: () {
      when(() => repository.restoreSession()).thenAnswer(
        (_) async => const Left(InternalFailure(ErrorTextRaw('no session'))),
      );
      return AuthenticationCubit(
        repository: repository,
        sessionService: sessionService,
      );
    },
    act: (cubit) => cubit.restoreSession(),
    expect: () => [const AuthenticationUnauthenticated()],
  );

  blocTest<AuthenticationCubit, AuthenticationState>(
    'setAuthenticated emits Authenticated with the given user',
    build: () => AuthenticationCubit(
      repository: repository,
      sessionService: sessionService,
    ),
    act: (cubit) => cubit.setAuthenticated(user),
    expect: () => [AuthenticationAuthenticated(user)],
  );

  blocTest<AuthenticationCubit, AuthenticationState>(
    'logout clears the session and emits Unauthenticated',
    build: () {
      when(() => repository.logout()).thenAnswer((_) async {});
      return AuthenticationCubit(
        repository: repository,
        sessionService: sessionService,
      );
    },
    seed: () => AuthenticationAuthenticated(user),
    act: (cubit) => cubit.logout(),
    expect: () => [const AuthenticationUnauthenticated()],
    verify: (_) => verify(() => repository.logout()).called(1),
  );

  blocTest<AuthenticationCubit, AuthenticationState>(
    'emits Unauthenticated when the session service reports the session expired',
    build: () => AuthenticationCubit(
      repository: repository,
      sessionService: sessionService,
    ),
    seed: () => AuthenticationAuthenticated(user),
    act: (_) => sessionService.notifySessionExpired(),
    expect: () => [const AuthenticationUnauthenticated()],
  );
}
