import 'package:beebase/core/storage/secure_storage.dart';

/// Securely persists the short-lived access token. The refresh token never
/// passes through here — it travels only as an HttpOnly cookie managed by
/// the cookie jar (see CookieManager registration in di.dart).
class TokenStorage {
  const TokenStorage({required this.secureStorage});

  static const _accessTokenKey = 'access_token';

  final SecureStorage secureStorage;

  Future<void> saveAccessToken(String accessToken) =>
      secureStorage.write(_accessTokenKey, accessToken);

  Future<String?> accessToken() => secureStorage.read(_accessTokenKey);

  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  Future<void> clear() => secureStorage.delete(_accessTokenKey);
}
