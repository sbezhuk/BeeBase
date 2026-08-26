import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/models/login_request.dart';
import 'package:beebase/data/models/register_request.dart';
import 'package:beebase/data/models/session_response.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// register/login/logout carry the refresh token as an HttpOnly cookie, so
/// they only need [CookieManager]. Only /me is bearer-authenticated.
final class AuthenticationDataSource implements IAuthenticationDataSource {
  AuthenticationDataSource({
    required DioClient dioClient,
    required InterceptorResolver resolver,
  }) : _publicClient = dioClient.copyWith(
         interceptors: [resolver.resolve<CookieManager>()],
       ),
       _authClient = dioClient.copyWith(
         interceptors: [
           resolver.resolve<CookieManager>(),
           resolver.resolve<AuthenticationInterceptor>(),
         ],
       );

  final DioClient _publicClient;
  final DioClient _authClient;

  @override
  Future<SessionResponse> register({
    required String email,
    required String password,
  }) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.authRegister,
      data: RegisterRequest(email: email, password: password).toJson(),
    );
    return SessionResponse.fromJson(response.data!);
  }

  @override
  Future<SessionResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      data: LoginRequest(email: email, password: password).toJson(),
    );
    return SessionResponse.fromJson(response.data!);
  }

  @override
  Future<UserResponse> getCurrentUser() async {
    final response = await _authClient.get<Map<String, dynamic>>(
      ApiEndpoints.authMe,
    );
    return UserResponse.fromJson(response.data!);
  }

  @override
  Future<void> logout() => _publicClient.post<void>(ApiEndpoints.authLogout);
}
