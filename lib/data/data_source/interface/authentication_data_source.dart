import 'package:beebase/data/models/session_response.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';

abstract interface class IAuthenticationDataSource {
  Future<TotpSetupChallenge> register({required String email, required String password});

  Future<AuthChallenge> login({required String email, required String password});

  Future<SessionResponse> verifyTotpSetup({required String setupToken, required String otp});

  Future<SessionResponse> verifyLoginOtp({required String challengeToken, required String otp});

  Future<UserResponse> getCurrentUser();

  Future<void> logout();
}
