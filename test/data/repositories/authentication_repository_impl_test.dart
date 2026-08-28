import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/session_response.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/data/repositories/authentication_repository_impl.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationDataSource extends Mock implements IAuthenticationDataSource {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockUserLocalDataSource extends Mock implements LocalDataSource<UserResponse> {}

void main() {
  late MockAuthenticationDataSource dataSource;
  late MockTokenStorage tokenStorage;
  late MockUserLocalDataSource userLocalDataSource;
  late AuthenticationRepositoryImpl repository;

  final userResponse = UserResponse(id: 'user-1', email: 'bee@example.com', createdAt: DateTime(2026));
  final sessionResponse = SessionResponse(
    accessToken: 'access-token',
    accessTokenExpiresAt: 1000,
    refreshTokenExpiresAt: 2000,
    user: userResponse,
  );

  setUpAll(() {
    registerFallbackValue(userResponse);
  });

  setUp(() {
    dataSource = MockAuthenticationDataSource();
    tokenStorage = MockTokenStorage();
    userLocalDataSource = MockUserLocalDataSource();
    repository = AuthenticationRepositoryImpl(
      dataSource: dataSource,
      tokenStorage: tokenStorage,
      userLocalDataSource: userLocalDataSource,
    );
    when(() => tokenStorage.saveAccessToken(any())).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
    when(() => userLocalDataSource.read()).thenAnswer((_) async => null);
    when(() => userLocalDataSource.write(any())).thenAnswer((_) async {});
    when(() => userLocalDataSource.clear()).thenAnswer((_) async {});
  });

  group('register', () {
    test('stores the access token and returns the mapped user on success', () async {
      when(
        () => dataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => sessionResponse);

      final result = await repository.register(email: 'bee@example.com', password: 'password123');

      expect(result, isA<Right<Failure, dynamic>>());
      result.fold((_) => fail('expected Right'), (user) => expect(user.email, 'bee@example.com'));
      verify(() => tokenStorage.saveAccessToken('access-token')).called(1);
    });

    test('maps a 409 email_taken exception to a ServerFailure', () async {
      when(
        () => dataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const ServerException(statusCode: 409, code: 'email_taken', message: 'already registered'));

      final result = await repository.register(email: 'bee@example.com', password: 'password123');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'email_taken')),
        (_) => fail('expected Left'),
      );
      verifyNever(() => tokenStorage.saveAccessToken(any()));
    });
  });

  group('login', () {
    test('stores the access token and returns the mapped user on success', () async {
      when(
        () => dataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => sessionResponse);

      final result = await repository.login(email: 'bee@example.com', password: 'password123');

      result.fold((_) => fail('expected Right'), (user) => expect(user.id, 'user-1'));
      verify(() => tokenStorage.saveAccessToken('access-token')).called(1);
    });

    test('maps invalid_credentials to a ServerFailure without storing a token', () async {
      when(
        () => dataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const ServerException(statusCode: 401, code: 'invalid_credentials', message: 'invalid email or password'));

      final result = await repository.login(email: 'bee@example.com', password: 'wrong');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'invalid_credentials')),
        (_) => fail('expected Left'),
      );
      verifyNever(() => tokenStorage.saveAccessToken(any()));
    });
  });

  group('getCurrentUser', () {
    test('returns the mapped user', () async {
      when(() => dataSource.getCurrentUser()).thenAnswer((_) async => userResponse);

      final result = await repository.getCurrentUser();

      result.fold((_) => fail('expected Right'), (user) => expect(user.email, 'bee@example.com'));
    });
  });

  group('restoreSession', () {
    test('fails fast without a network call when no token was ever stored', () async {
      when(() => tokenStorage.hasAccessToken()).thenAnswer((_) async => false);

      final result = await repository.restoreSession();

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => dataSource.getCurrentUser());
    });

    test('fetches the current user when a token is stored', () async {
      when(() => tokenStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(() => dataSource.getCurrentUser()).thenAnswer((_) async => userResponse);

      final result = await repository.restoreSession();

      result.fold((_) => fail('expected Right'), (user) => expect(user.id, 'user-1'));
    });

    test('propagates a failure if the stored token could not be validated even after refresh', () async {
      when(() => tokenStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(
        () => dataSource.getCurrentUser(),
      ).thenThrow(const ServerException(statusCode: 401, code: 'invalid_access_token', message: 'expired'));

      final result = await repository.restoreSession();

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('falls back to the cached user when getCurrentUser fails due to connectivity', () async {
      when(() => tokenStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(() => dataSource.getCurrentUser()).thenThrow(const InternalException(ErrorTextRaw('no connection')));
      when(() => userLocalDataSource.read()).thenAnswer((_) async => userResponse);

      final result = await repository.restoreSession();

      result.fold((_) => fail('expected Right'), (user) => expect(user.id, 'user-1'));
    });

    test('propagates the connectivity failure when offline with no cached user', () async {
      when(() => tokenStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(() => dataSource.getCurrentUser()).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.restoreSession();

      expect(result, isA<Left<Failure, dynamic>>());
    });

    test('does not fall back to a cached user when the server rejects the token', () async {
      when(() => tokenStorage.hasAccessToken()).thenAnswer((_) async => true);
      when(
        () => dataSource.getCurrentUser(),
      ).thenThrow(const ServerException(statusCode: 401, code: 'invalid_access_token', message: 'expired'));
      when(() => userLocalDataSource.read()).thenAnswer((_) async => userResponse);

      final result = await repository.restoreSession();

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => userLocalDataSource.read());
    });
  });

  group('logout', () {
    test('clears the local session even when the network call fails', () async {
      when(() => dataSource.logout()).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      await repository.logout();

      verify(() => tokenStorage.clear()).called(1);
    });

    test('clears the local session on success', () async {
      when(() => dataSource.logout()).thenAnswer((_) async {});

      await repository.logout();

      verify(() => tokenStorage.clear()).called(1);
    });
  });
}
