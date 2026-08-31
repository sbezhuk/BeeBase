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
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
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
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
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

  test(
    'listMedia sends owner_type/owner_id query params and maps the page',
    () async {
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
            'pagination': {
              'page': 1,
              'limit': 20,
              'total': 1,
              'total_pages': 1,
              'has_next': false,
              'has_previous': false,
            },
          },
        ),
      );

      final result = await dataSource.listMedia(
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        request: const PageRequest(page: 1, limit: 20),
      );

      expect(result.items.single.id, 'media-1');
      final captured =
          verify(
                () => innerDioClient.get<Map<String, dynamic>>(
                  ApiEndpoints.media.list,
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['owner_type'], 'apiary');
      expect(captured['owner_id'], 'apiary-1');
      expect(captured['page'], 1);
      expect(captured['limit'], 20);
    },
  );

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
      'posts multipart form data (including the idempotency key) and maps the response',
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
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          filePath: file.path,
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
          idempotencyKey: 'op-1',
        );

        expect(result.id, 'media-1');
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
        expect(fields['owner_type'], 'apiary');
        expect(fields['owner_id'], 'apiary-1');
        expect(fields['media_id'], 'op-1');
        expect(captured.files.single.key, 'file');
      },
    );

    test('omits media_id when no idempotency key is given', () async {
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

      await dataSource.uploadMedia(
        ownerType: MediaOwnerType.hive,
        ownerId: 'hive-1',
        filePath: file.path,
        originalFilename: 'photo.jpg',
        contentType: 'image/jpeg',
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
      expect(fields.containsKey('media_id'), isFalse);
      expect(fields['owner_type'], 'hive');
    });
  });

  test('downloadMedia fetches raw bytes from the download endpoint', () async {
    when(() => innerDioClient.getBytes(any())).thenAnswer(
      (_) async => Response(requestOptions: RequestOptions(), data: [1, 2, 3]),
    );

    final bytes = await dataSource.downloadMedia('media-1');

    expect(bytes, [1, 2, 3]);
    verify(
      () => innerDioClient.getBytes(ApiEndpoints.media.download('media-1')),
    ).called(1);
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
