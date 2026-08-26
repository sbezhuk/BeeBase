import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

class MockTokenRefresher extends Mock implements TokenRefresher {}

class MockSessionService extends Mock implements SessionService {}

class MockDio extends Mock implements Dio {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  late MockTokenStorage tokenStorage;
  late MockTokenRefresher tokenRefresher;
  late MockSessionService sessionService;
  late MockDio retryDio;
  late AuthenticationInterceptor interceptor;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/api/v1/auth/me'));
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '/api/v1/auth/me')),
    );
    registerFallbackValue(
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/auth/me'),
      ),
    );
  });

  setUp(() {
    tokenStorage = MockTokenStorage();
    tokenRefresher = MockTokenRefresher();
    sessionService = MockSessionService();
    retryDio = MockDio();
    interceptor = AuthenticationInterceptor(
      tokenStorage: tokenStorage,
      tokenRefresher: tokenRefresher,
      sessionService: sessionService,
      retryDio: retryDio,
    );
  });

  group('onRequest', () {
    test('attaches the bearer token when one is stored', () async {
      when(
        () => tokenStorage.accessToken(),
      ).thenAnswer((_) async => 'access-token');
      final options = RequestOptions(path: '/api/v1/auth/me');
      final handler = MockRequestInterceptorHandler();

      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer access-token');
      verify(() => handler.next(options)).called(1);
    });

    test(
      'rejects and notifies the session service when no token is stored',
      () async {
        when(() => tokenStorage.accessToken()).thenAnswer((_) async => null);
        final options = RequestOptions(path: '/api/v1/auth/me');
        final handler = MockRequestInterceptorHandler();

        await interceptor.onRequest(options, handler);

        verify(() => sessionService.notifySessionExpired()).called(1);
        verify(() => handler.reject(any())).called(1);
        verifyNever(() => handler.next(any()));
      },
    );
  });

  group('onError', () {
    test('forwards non-401 errors without attempting a refresh', () async {
      final err = DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/me'),
          statusCode: 500,
        ),
      );
      final handler = MockErrorInterceptorHandler();

      await interceptor.onError(err, handler);

      verifyNever(() => tokenRefresher.refresh());
      verify(() => handler.next(err)).called(1);
    });

    test('refreshes and retries the original request on a 401', () async {
      final requestOptions = RequestOptions(path: '/api/v1/auth/me');
      final err = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = MockErrorInterceptorHandler();
      when(() => tokenRefresher.refresh()).thenAnswer((_) async => 'new-token');
      when(() => retryDio.fetch<dynamic>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: 'ok',
        ),
      );

      await interceptor.onError(err, handler);

      expect(requestOptions.headers['Authorization'], 'Bearer new-token');
      verify(() => retryDio.fetch<dynamic>(requestOptions)).called(1);
      verify(() => handler.resolve(any())).called(1);
      verifyNever(() => handler.next(any()));
    });

    test('forwards the original error when refresh fails', () async {
      final requestOptions = RequestOptions(path: '/api/v1/auth/me');
      final err = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );
      final handler = MockErrorInterceptorHandler();
      when(() => tokenRefresher.refresh()).thenAnswer((_) async => null);

      await interceptor.onError(err, handler);

      verifyNever(() => retryDio.fetch<dynamic>(any()));
      verify(() => handler.next(err)).called(1);
    });
  });
}
