import 'dart:async';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/password_change_data_source.dart';
import 'package:beebase/data/data_source/interface/password_reset_data_source.dart';
import 'package:beebase/data/models/extensions/password_reset_otp_verified_response_extension.dart';
import 'package:beebase/data/models/extensions/password_reset_requested_response_extension.dart';
import 'package:beebase/data/models/extensions/user_extension.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/entity/password_reset_flow.dart';
import 'package:beebase/domain/entity/password_reset_verification.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/domain/repositories/password_changer.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

final class AuthenticationRepositoryImpl extends Repository
    implements AuthenticationRepository, IPasswordChanger, IPasswordResetFlow {
  AuthenticationRepositoryImpl({
    required this.dataSource,
    required this.passwordChangeDataSource,
    required this.passwordResetDataSource,
    required this.tokenStorage,
    required this.userLocalDataSource,
  });

  final IAuthenticationDataSource dataSource;
  final IPasswordChangeDataSource passwordChangeDataSource;
  final IPasswordResetDataSource passwordResetDataSource;
  final TokenStorage tokenStorage;
  final LocalDataSource<UserResponse> userLocalDataSource;

  // No token-storage side effect here — neither call issues a session
  // anymore, only a challenge that verifyTotpSetup/verifyLoginOtp resolves.
  @override
  Future<Either<Failure, TotpSetupChallenge>> register({required String email, required String password}) {
    return on(() => dataSource.register(email: email, password: password));
  }

  @override
  Future<Either<Failure, AuthChallenge>> login({required String email, required String password}) {
    return on(() => dataSource.login(email: email, password: password));
  }

  @override
  Future<Either<Failure, User>> verifyTotpSetup({required String setupToken, required String otp}) {
    return on(() async {
      final session = await dataSource.verifyTotpSetup(setupToken: setupToken, otp: otp);
      await tokenStorage.saveAccessToken(session.accessToken);
      // See the comment on the old register()/login() bodies this replaced —
      // only the offline restoreSession fallback ever reads this cache.
      unawaited(userLocalDataSource.write(session.user).catchError((_) {}));
      return session.user.toEntity();
    });
  }

  @override
  Future<Either<Failure, User>> verifyLoginOtp({required String challengeToken, required String otp}) {
    return on(() async {
      final session = await dataSource.verifyLoginOtp(challengeToken: challengeToken, otp: otp);
      await tokenStorage.saveAccessToken(session.accessToken);
      unawaited(userLocalDataSource.write(session.user).catchError((_) {}));
      return session.user.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) {
    return on(
      () => passwordChangeDataSource.changePassword(currentPassword: currentPassword, newPassword: newPassword, otp: otp),
    );
  }

  @override
  Future<Either<Failure, PasswordResetFlow>> requestPasswordReset({required String email}) {
    return on(() async {
      final response = await passwordResetDataSource.requestPasswordReset(email: email);
      return response.toEntity();
    });
  }

  @override
  Future<Either<Failure, PasswordResetVerification>> verifyPasswordResetOtp({
    required String flowToken,
    required String otp,
  }) {
    return on(() async {
      final response = await passwordResetDataSource.verifyPasswordResetOtp(flowToken: flowToken, otp: otp);
      return response.toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) {
    return on(
      () => passwordResetDataSource.confirmPasswordReset(
        resetToken: resetToken,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
    );
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() {
    return on(() async {
      final user = await dataSource.getCurrentUser();
      await userLocalDataSource.write(user);
      return user.toEntity();
    });
  }

  /// Restores a previously established session. A network failure here
  /// (no connectivity, timeout) does not mean the session is invalid — it
  /// falls back to the last known user so the app stays usable offline.
  /// Only a failure from the server itself (it explicitly rejected the
  /// token) is treated as a real logout.
  @override
  Future<Either<Failure, User>> restoreSession() async {
    final hasSession = await tokenStorage.hasAccessToken();
    if (!hasSession) {
      return const Left(InternalFailure(ErrorTextKey('core.errors.no_active_session')));
    }

    final result = await getCurrentUser();
    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      final cachedUser = await userLocalDataSource.read();
      return cachedUser == null ? Left(failure) : Right(cachedUser.toEntity());
    }, (user) => Future.value(Right(user)));
  }

  @override
  Future<void> logout() async {
    try {
      await dataSource.logout();
    } catch (_) {
      // Best-effort: the local session is cleared below regardless of
      // whether the server could be reached to revoke the refresh token.
    }
    await tokenStorage.clear();
    await userLocalDataSource.clear();
  }
}
