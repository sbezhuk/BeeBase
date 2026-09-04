/// `/api/v1/auth/*` paths. Reached through `ApiEndpoints.auth`.
final class AuthEndpoints {
  const AuthEndpoints();

  String get register => '/api/v1/auth/register';
  String get login => '/api/v1/auth/login';
  String get totpSetupVerify => '/api/v1/auth/2fa/setup/verify';
  String get loginVerifyOtp => '/api/v1/auth/login/verify-otp';
  String get changePassword => '/api/v1/auth/change-password';
  String get passwordResetRequest => '/api/v1/auth/password-reset/request';
  String get passwordResetVerifyOtp => '/api/v1/auth/password-reset/verify-otp';
  String get passwordResetConfirm => '/api/v1/auth/password-reset/confirm';
  String get refresh => '/api/v1/auth/refresh';
  String get logout => '/api/v1/auth/logout';
  String get me => '/api/v1/auth/me';
}
