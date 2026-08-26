import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDioClient extends Mock implements DioClient {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockSessionService extends Mock implements SessionService {}

void main() {
  late MockDioClient dioClient;
  late MockTokenStorage tokenStorage;
  late MockSessionService sessionService;
  late TokenRefresher tokenRefresher;

  setUp(() {
    dioClient = MockDioClient();
    tokenStorage = MockTokenStorage();
    sessionService = MockSessionService();
    tokenRefresher = TokenRefresher(
      dioClient: dioClient,
      tokenStorage: tokenStorage,
      sessionService: sessionService,
    );
  });

  test('persists and returns the new access token on success', () async {
    when(
      () => dioClient.post<Map<String, dynamic>>('/api/v1/auth/refresh'),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {'access_token': 'new-token', 'access_token_expires_at': 123},
      ),
    );
    when(() => tokenStorage.saveAccessToken(any())).thenAnswer((_) async {});

    final result = await tokenRefresher.refresh();

    expect(result, 'new-token');
    verify(() => tokenStorage.saveAccessToken('new-token')).called(1);
    verifyNever(() => sessionService.notifySessionExpired());
  });

  test(
    'clears the session and notifies listeners when the server rejects the refresh token',
    () async {
      when(
        () => dioClient.post<Map<String, dynamic>>('/api/v1/auth/refresh'),
      ).thenThrow(
        const ServerException(
          statusCode: 401,
          code: 'invalid_refresh_token',
          message: 'invalid',
        ),
      );
      when(() => tokenStorage.clear()).thenAnswer((_) async {});

      final result = await tokenRefresher.refresh();

      expect(result, isNull);
      verify(() => tokenStorage.clear()).called(1);
      verify(() => sessionService.notifySessionExpired()).called(1);
    },
  );

  test(
    'returns null without clearing the session on a network error',
    () async {
      when(
        () => dioClient.post<Map<String, dynamic>>('/api/v1/auth/refresh'),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await tokenRefresher.refresh();

      expect(result, isNull);
      verifyNever(() => tokenStorage.clear());
      verifyNever(() => sessionService.notifySessionExpired());
    },
  );
}
