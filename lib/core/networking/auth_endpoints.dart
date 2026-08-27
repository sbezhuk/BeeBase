/// `/api/v1/auth/*` paths. Reached through `ApiEndpoints.auth`.
final class AuthEndpoints {
  const AuthEndpoints();

  String get register => '/api/v1/auth/register';
  String get login => '/api/v1/auth/login';
  String get refresh => '/api/v1/auth/refresh';
  String get logout => '/api/v1/auth/logout';
  String get me => '/api/v1/auth/me';
}
