import 'package:beebase/data/models/session_response.dart';
import 'package:beebase/data/models/user_response.dart';

abstract interface class IAuthenticationDataSource {
  Future<SessionResponse> register({
    required String email,
    required String password,
  });

  Future<SessionResponse> login({
    required String email,
    required String password,
  });

  Future<UserResponse> getCurrentUser();

  Future<void> logout();
}
