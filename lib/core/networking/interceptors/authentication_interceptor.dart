import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

/// Attaches the bearer access token to every request — or fails the request
/// immediately if no token is stored, since there is definitely no valid
/// session to attach. On a 401 it rotates the token via [TokenRefresher] and
/// retries the original request once; if the refresh itself fails, the local
/// session is cleared and [SessionService] notifies listeners so the app can
/// navigate back to login.
final class AuthenticationInterceptor extends QueuedInterceptorsWrapper {
  AuthenticationInterceptor({
    required this.tokenStorage,
    required this.tokenRefresher,
    required this.sessionService,
    Dio? retryDio,
  }) : retryDio = retryDio ?? Dio();

  final TokenStorage tokenStorage;
  final TokenRefresher tokenRefresher;
  final SessionService sessionService;

  /// Used only to re-issue the original request after a successful refresh —
  /// injectable so tests don't need a real network call.
  final Dio retryDio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.accessToken();
    if (token == null) {
      sessionService.notifySessionExpired();
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'core.errors.noActiveSession'.tr(),
          type: DioExceptionType.cancel,
        ),
      );
      return;
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final newAccessToken = await tokenRefresher.refresh();
    if (newAccessToken == null) {
      handler.next(err);
      return;
    }

    final retryOptions = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newAccessToken';
    try {
      final response = await retryDio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
