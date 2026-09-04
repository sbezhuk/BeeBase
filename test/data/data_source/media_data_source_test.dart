import 'dart:io';

import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/media_data_source.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDioClient extends Mock implements DioClient {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockTokenRefresher extends Mock implements TokenRefresher {}

class MockSessionService extends Mock implements SessionService {}

void main() {
  late MockDioClient outerDioClient;
  late MockDioClient innerDioClient;
  late MediaDataSource dataSource;

  final mediaResponse = MediaResponse(
    id: 'media-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    imageUrl: 'https://api.beebase.test/api/v1/media/media-1/download',
  );

  setUp(() {
    outerDioClient = MockDioClient();
    innerDioClient = MockDioClient();
    when(
      () => outerDioClient.copyWith(interceptors: any(named: 'interceptors')),
    ).thenReturn(innerDioClient);
    // A real AuthenticationInterceptor, matching AuthenticationInterceptorTest's own
    // approach — it has no data-source-relevant behavior here, it just needs to
    // exist so InterceptorResolver.resolve<AuthenticationInterceptor>() succeeds.
    final interceptor = AuthenticationInterceptor(
      tokenStorage: MockTokenStorage(),
      tokenRefresher: MockTokenRefresher(),
      sessionService: MockSessionService(),
    );
    final resolver = InterceptorResolver({
      AuthenticationInterceptor: interceptor,
    });
    dataSource = MediaDataSource(dioClient: outerDioClient, resolver: resolver);
  });

  test('listMedia sends a repeated ids query param and parses the flat, '
      'unpaginated {items: [...]} response', () async {
    when(
      () => innerDioClient.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'items': [mediaResponse.toJson()],
        },
      ),
    );

    final result = await dataSource.listMedia(ids: ['media-1', 'media-2']);

    expect(result.single.id, 'media-1');
    final captured =
        verify(
              () => innerDioClient.get<Map<String, dynamic>>(
                ApiEndpoints.media.list,
                queryParameters: captureAny(named: 'queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured['ids'], ['media-1', 'media-2']);
  });

  group('uploadMedia', () {
    late Directory tempDir;
    late File file;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('media_data_source_test');
      file = File('${tempDir.path}/photo.jpg');
      await file.writeAsBytes([1, 2, 3]);
    });

    tearDown(() => tempDir.delete(recursive: true));

    test(
      'posts multipart form data and returns '
      "the server's own record — including the image_url every later render "
      'of the photo goes through',
      () async {
        when(
          () => innerDioClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(),
            data: mediaResponse.toJson(),
          ),
        );

        final result = await dataSource.uploadMedia(
          filePath: file.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        expect(result.id, 'media-1');
        expect(
          result.imageUrl,
          'https://api.beebase.test/api/v1/media/media-1/download',
        );
        final captured =
            verify(
                  () => innerDioClient.post<Map<String, dynamic>>(
                    ApiEndpoints.media.list,
                    data: captureAny(named: 'data'),
                    onSendProgress: any(named: 'onSendProgress'),
                  ),
                ).captured.single
                as FormData;
        final fields = Map.fromEntries(captured.fields);
        expect(fields.containsKey('owner_type'), isFalse);
        expect(fields.containsKey('owner_id'), isFalse);
        expect(captured.files.single.key, 'file');
      },
    );
  });

  test('deleteMedia calls delete on the byId endpoint', () async {
    when(
      () => innerDioClient.delete<void>(any()),
    ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

    await dataSource.deleteMedia('media-1');

    verify(
      () => innerDioClient.delete<void>(ApiEndpoints.media.byId('media-1')),
    ).called(1);
  });
}
