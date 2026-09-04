import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/password_change_data_source.dart';
import 'package:beebase/data/data_source/interface/password_reset_data_source.dart';
import 'package:beebase/data/models/change_password_request.dart';
import 'package:beebase/data/models/extensions/login_otp_required_response_extension.dart';
import 'package:beebase/data/models/extensions/totp_setup_response_extension.dart';
import 'package:beebase/data/models/login_otp_required_response.dart';
import 'package:beebase/data/models/login_request.dart';
import 'package:beebase/data/models/login_verify_otp_request.dart';
import 'package:beebase/data/models/password_reset_confirm_request.dart';
import 'package:beebase/data/models/password_reset_otp_verified_response.dart';
import 'package:beebase/data/models/password_reset_request_request.dart';
import 'package:beebase/data/models/password_reset_requested_response.dart';
import 'package:beebase/data/models/password_reset_verify_otp_request.dart';
import 'package:beebase/data/models/register_request.dart';
import 'package:beebase/data/models/session_response.dart';
import 'package:beebase/data/models/setup_verify_request.dart';
import 'package:beebase/data/models/totp_setup_response.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// register/login/2fa-setup-verify/login-verify-otp/password-reset all carry
/// the refresh token as an HttpOnly cookie (when they issue one at all), so
/// they only need [CookieManager]. Only /me and /change-password are
/// bearer-authenticated.
final class AuthenticationDataSource
    implements IAuthenticationDataSource, IPasswordChangeDataSource, IPasswordResetDataSource {
  AuthenticationDataSource({required DioClient dioClient, required InterceptorResolver resolver})
    : _publicClient = dioClient.copyWith(interceptors: [resolver.resolve<CookieManager>()]),
      _authClient = dioClient.copyWith(
        interceptors: [resolver.resolve<CookieManager>(), resolver.resolve<AuthenticationInterceptor>()],
      );

  final DioClient _publicClient;
  final DioClient _authClient;

  @override
  Future<TotpSetupChallenge> register({required String email, required String password}) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.auth.register,
      data: RegisterRequest(email: email, password: password).toJson(),
    );
    return TotpSetupResponse.fromJson(response.data!).toEntity();
  }

  @override
  Future<AuthChallenge> login({required String email, required String password}) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.auth.login,
      data: LoginRequest(email: email, password: password).toJson(),
    );
    final json = response.data!;
    return switch (json['status']) {
      'otp_required' => LoginOtpRequiredResponse.fromJson(json).toEntity(),
      _ => TotpSetupResponse.fromJson(json).toEntity(),
    };
  }

  @override
  Future<SessionResponse> verifyTotpSetup({required String setupToken, required String otp}) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.auth.totpSetupVerify,
      data: SetupVerifyRequest(setupToken: setupToken, otp: otp).toJson(),
    );
    return SessionResponse.fromJson(response.data!);
  }

  @override
  Future<SessionResponse> verifyLoginOtp({required String challengeToken, required String otp}) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.auth.loginVerifyOtp,
      data: LoginVerifyOtpRequest(challengeToken: challengeToken, otp: otp).toJson(),
    );
    return SessionResponse.fromJson(response.data!);
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword, required String otp}) {
    return _authClient.post<void>(
      ApiEndpoints.auth.changePassword,
      data: ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword, otp: otp).toJson(),
    );
  }

  @override
  Future<PasswordResetRequestedResponse> requestPasswordReset({required String email}) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.auth.passwordResetRequest,
      data: PasswordResetRequestRequest(email: email).toJson(),
    );
    return PasswordResetRequestedResponse.fromJson(response.data!);
  }

  @override
  Future<PasswordResetOtpVerifiedResponse> verifyPasswordResetOtp({required String flowToken, required String otp}) async {
    final response = await _publicClient.post<Map<String, dynamic>>(
      ApiEndpoints.auth.passwordResetVerifyOtp,
      data: PasswordResetVerifyOtpRequest(flowToken: flowToken, otp: otp).toJson(),
    );
    return PasswordResetOtpVerifiedResponse.fromJson(response.data!);
  }

  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _publicClient.post<void>(
      ApiEndpoints.auth.passwordResetConfirm,
      data: PasswordResetConfirmRequest(
        resetToken: resetToken,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ).toJson(),
    );
  }

  @override
  Future<UserResponse> getCurrentUser() async {
    final response = await _authClient.get<Map<String, dynamic>>(ApiEndpoints.auth.me);
    return UserResponse.fromJson(response.data!);
  }

  @override
  Future<void> logout() => _publicClient.post<void>(ApiEndpoints.auth.logout);
}
