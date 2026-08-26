import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/exceptions/cancellation_exception.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/token_storage.dart';

/// Rotates the refresh token (sent automatically as an HttpOnly cookie by
/// [dioClient]'s cookie interceptor) for a new access/refresh pair, and
/// persists the new access token. Kept separate from the authentication data
/// source so [AuthenticationInterceptor] can depend on it without creating a
/// dependency cycle back through the data source that needs the interceptor.
class TokenRefresher {
  const TokenRefresher({
    required this.dioClient,
    required this.tokenStorage,
    required this.sessionService,
  });

  final DioClient dioClient;
  final TokenStorage tokenStorage;
  final SessionService sessionService;

  /// Returns the new access token on success, or `null` if the refresh token
  /// is missing/expired/revoked — in which case the local session is cleared
  /// and listeners are notified so the app can navigate back to login.
  Future<String?> refresh() async {
    try {
      final response = await dioClient.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
      );
      final accessToken = response.data?['access_token'] as String?;
      if (accessToken == null) {
        return null;
      }
      await tokenStorage.saveAccessToken(accessToken);
      return accessToken;
    } on ServerException {
      await tokenStorage.clear();
      sessionService.notifySessionExpired();
      return null;
    } on CancellationException {
      return null;
    } on InternalException {
      return null;
    }
  }
}
