import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/password_change_data_source.dart';
import 'package:beebase/data/data_source/interface/password_reset_data_source.dart';
import 'package:beebase/data/models/password_reset_otp_verified_response.dart';
import 'package:beebase/data/models/password_reset_requested_response.dart';
import 'package:beebase/data/models/session_response.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/data/repositories/authentication_repository_impl.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationDataSource extends Mock implements IAuthenticationDataSource {}

class MockPasswordChangeDataSource extends Mock implements IPasswordChangeDataSource {}

class MockPasswordResetDataSource extends Mock implements IPasswordResetDataSource {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockUserLocalDataSource extends Mock implements LocalDataSource<UserResponse> {}

void main() {
  late MockAuthenticationDataSource dataSource;
  late MockPasswordChangeDataSource passwordChangeDataSource;
  late MockPasswordResetDataSource passwordResetDataSource;
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
  final totpSetupChallenge = TotpSetupChallenge(
    setupToken: 'setup-token',
    otpauthUri: 'otpauth://totp/BeeBase:bee@example.com?secret=JBSWY3DPEHPK3PXP&issuer=BeeBase',
    secret: 'JBSWY3DPEHPK3PXP',
    expiresAt: DateTime(2026),
  );
  final loginOtpChallenge = LoginOtpChallenge(challengeToken: 'challenge-token', expiresAt: DateTime(2026));

  setUpAll(() {
    registerFallbackValue(userResponse);
  });

  setUp(() {
    dataSource = MockAuthenticationDataSource();
    passwordChangeDataSource = MockPasswordChangeDataSource();
    passwordResetDataSource = MockPasswordResetDataSource();
    tokenStorage = MockTokenStorage();
    userLocalDataSource = MockUserLocalDataSource();
    repository = AuthenticationRepositoryImpl(
      dataSource: dataSource,
      passwordChangeDataSource: passwordChangeDataSource,
      passwordResetDataSource: passwordResetDataSource,
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
    test('returns the TOTP setup challenge without storing a token', () async {
      when(
        () => dataSource.register(email: any(named: 'email'), password: any(named: 'password')),
      ).thenAnswer((_) async => totpSetupChallenge);

      final result = await repository.register(email: 'bee@example.com', password: 'password123');

      result.fold((_) => fail('expected Right'), (challenge) => expect(challenge, totpSetupChallenge));
      verifyNever(() => tokenStorage.saveAccessToken(any()));
    });

    test('maps a 409 email_taken exception to a ServerFailure', () async {
      when(
        () => dataSource.register(email: any(named: 'email'), password: any(named: 'password')),
      ).thenThrow(const ServerException(statusCode: 409, code: 'email_taken', message: 'already registered'));

      final result = await repository.register(email: 'bee@example.com', password: 'password123');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'email_taken')),
        (_) => fail('expected Left'),
      );
    });
  });

  group('login', () {
    test('returns the challenge without storing a token', () async {
      when(
        () => dataSource.login(email: any(named: 'email'), password: any(named: 'password')),
      ).thenAnswer((_) async => loginOtpChallenge);

      final result = await repository.login(email: 'bee@example.com', password: 'password123');

      result.fold((_) => fail('expected Right'), (challenge) => expect(challenge, loginOtpChallenge));
      verifyNever(() => tokenStorage.saveAccessToken(any()));
    });

    test('maps invalid_credentials to a ServerFailure', () async {
      when(
        () => dataSource.login(email: any(named: 'email'), password: any(named: 'password')),
      ).thenThrow(
        const ServerException(statusCode: 401, code: 'invalid_credentials', message: 'invalid email or password'),
      );

      final result = await repository.login(email: 'bee@example.com', password: 'wrong');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'invalid_credentials')),
        (_) => fail('expected Left'),
      );
    });
  });

  group('verifyTotpSetup', () {
    test('stores the access token and returns the mapped user on success', () async {
      when(
        () => dataSource.verifyTotpSetup(setupToken: any(named: 'setupToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => sessionResponse);

      final result = await repository.verifyTotpSetup(setupToken: 'setup-token', otp: '123456');

      result.fold((_) => fail('expected Right'), (user) => expect(user.email, 'bee@example.com'));
      verify(() => tokenStorage.saveAccessToken('access-token')).called(1);
    });

    test('maps otp_invalid to a ServerFailure without storing a token', () async {
      when(
        () => dataSource.verifyTotpSetup(setupToken: any(named: 'setupToken'), otp: any(named: 'otp')),
      ).thenThrow(const ServerException(statusCode: 401, code: 'otp_invalid', message: 'wrong code'));

      final result = await repository.verifyTotpSetup(setupToken: 'setup-token', otp: '000000');

      expect(result, isA<Left<Failure, dynamic>>());
      verifyNever(() => tokenStorage.saveAccessToken(any()));
    });
  });

  group('verifyLoginOtp', () {
    test('stores the access token and returns the mapped user on success', () async {
      when(
        () => dataSource.verifyLoginOtp(challengeToken: any(named: 'challengeToken'), otp: any(named: 'otp')),
      ).thenAnswer((_) async => sessionResponse);

      final result = await repository.verifyLoginOtp(challengeToken: 'challenge-token', otp: '123456');

      result.fold((_) => fail('expected Right'), (user) => expect(user.id, 'user-1'));
      verify(() => tokenStorage.saveAccessToken('access-token')).called(1);
    });

    test('maps otp_locked to a ServerFailure', () async {
      when(
        () => dataSource.verifyLoginOtp(challengeToken: any(named: 'challengeToken'), otp: any(named: 'otp')),
      ).thenThrow(const ServerException(statusCode: 429, code: 'otp_locked', message: 'too many attempts'));

      final result = await repository.verifyLoginOtp(challengeToken: 'challenge-token', otp: '000000');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'otp_locked')),
        (_) => fail('expected Left'),
      );
    });
  });

  group('changePassword', () {
    test('succeeds', () async {
      when(
        () => passwordChangeDataSource.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
        otp: '123456',
      );

      expect(result, isA<Right<Failure, dynamic>>());
    });

    test('maps current_password_invalid to a ServerFailure', () async {
      when(
        () => passwordChangeDataSource.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
          otp: any(named: 'otp'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 401, code: 'current_password_invalid', message: 'wrong password'),
      );

      final result = await repository.changePassword(
        currentPassword: 'wrong-password',
        newPassword: 'new-password',
        otp: '123456',
      );

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'current_password_invalid')),
        (_) => fail('expected Left'),
      );
    });
  });

  group('requestPasswordReset', () {
    test('returns the mapped flow', () async {
      when(() => passwordResetDataSource.requestPasswordReset(email: any(named: 'email'))).thenAnswer(
        (_) async => PasswordResetRequestedResponse(flowToken: 'flow-token', expiresAt: 1000),
      );

      final result = await repository.requestPasswordReset(email: 'bee@example.com');

      result.fold((_) => fail('expected Right'), (flow) => expect(flow.flowToken, 'flow-token'));
    });
  });

  group('verifyPasswordResetOtp', () {
    test('returns the mapped verification on success', () async {
      when(
        () => passwordResetDataSource.verifyPasswordResetOtp(
          flowToken: any(named: 'flowToken'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer((_) async => PasswordResetOtpVerifiedResponse(resetToken: 'reset-token', expiresAt: 1000));

      final result = await repository.verifyPasswordResetOtp(flowToken: 'flow-token', otp: '123456');

      result.fold((_) => fail('expected Right'), (verification) => expect(verification.resetToken, 'reset-token'));
    });

    test('maps otp_invalid to a ServerFailure', () async {
      when(
        () => passwordResetDataSource.verifyPasswordResetOtp(
          flowToken: any(named: 'flowToken'),
          otp: any(named: 'otp'),
        ),
      ).thenThrow(const ServerException(statusCode: 401, code: 'otp_invalid', message: 'wrong code'));

      final result = await repository.verifyPasswordResetOtp(flowToken: 'flow-token', otp: '000000');

      expect(result, isA<Left<Failure, dynamic>>());
    });
  });

  group('confirmPasswordReset', () {
    test('succeeds', () async {
      when(
        () => passwordResetDataSource.confirmPasswordReset(
          resetToken: any(named: 'resetToken'),
          newPassword: any(named: 'newPassword'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.confirmPasswordReset(
        resetToken: 'reset-token',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );

      expect(result, isA<Right<Failure, dynamic>>());
    });

    test('maps password_reset_token_invalid to a ServerFailure', () async {
      when(
        () => passwordResetDataSource.confirmPasswordReset(
          resetToken: any(named: 'resetToken'),
          newPassword: any(named: 'newPassword'),
          confirmPassword: any(named: 'confirmPassword'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 400, code: 'password_reset_token_invalid', message: 'expired'),
      );

      final result = await repository.confirmPasswordReset(
        resetToken: 'reset-token',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );

      expect(result, isA<Left<Failure, dynamic>>());
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
