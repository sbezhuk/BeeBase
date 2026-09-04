import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/utils/either.dart';

abstract interface class AuthenticationRepository {
  Future<Either<Failure, TotpSetupChallenge>> register({required String email, required String password});

  Future<Either<Failure, AuthChallenge>> login({required String email, required String password});

  Future<Either<Failure, User>> verifyTotpSetup({required String setupToken, required String otp});

  Future<Either<Failure, User>> verifyLoginOtp({required String challengeToken, required String otp});

  Future<Either<Failure, User>> getCurrentUser();

  /// Restores a previously established session on app startup. Fails fast
  /// (without a network call) if no access token was ever stored.
  Future<Either<Failure, User>> restoreSession();

  /// Always clears the local session, even if the network call fails.
  Future<void> logout();
}
