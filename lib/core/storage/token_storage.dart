import 'package:beebase/core/storage/secure_storage.dart';

/// Securely persists the short-lived access token. The refresh token never
/// passes through here — it travels only as an HttpOnly cookie managed by
/// the cookie jar (see CookieManager registration in di.dart).
///
/// Registered as a lazy singleton (see di.dart), so [_cachedAccessToken]
/// mirrors the keystore for the lifetime of the app: it lets [accessToken]
/// and [hasAccessToken] answer without a platform-channel round trip once a
/// token has been saved or read at least once — most notably on the
/// [AuthenticationGuard] check that immediately follows login.
class TokenStorage {
  TokenStorage({required this.secureStorage});

  static const _accessTokenKey = 'access_token';

  final SecureStorage secureStorage;

  String? _cachedAccessToken;

  Future<void> saveAccessToken(String accessToken) {
    _cachedAccessToken = accessToken;
    return secureStorage.write(_accessTokenKey, accessToken);
  }

  Future<String?> accessToken() async {
    return _cachedAccessToken ??= await secureStorage.read(_accessTokenKey);
  }

  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  Future<void> clear() {
    _cachedAccessToken = null;
    return secureStorage.delete(_accessTokenKey);
  }
}
