/// Path constants for the BeeBase API, shared between data sources and the
/// networking layer (e.g. [TokenRefresher] needs the refresh path without
/// depending on the data layer).
abstract final class ApiEndpoints {
  static const authRegister = '/api/v1/auth/register';
  static const authLogin = '/api/v1/auth/login';
  static const authRefresh = '/api/v1/auth/refresh';
  static const authLogout = '/api/v1/auth/logout';
  static const authMe = '/api/v1/auth/me';
}
