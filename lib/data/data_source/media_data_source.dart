import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/media_list_request.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:dio/dio.dart' as dio;

final class MediaDataSource implements IMediaDataSource {
  MediaDataSource({required DioClient dioClient, required InterceptorResolver resolver})
    : _dioClient = dioClient.copyWith(interceptors: [resolver.resolve<AuthenticationInterceptor>()]);

  final DioClient _dioClient;

  @override
  Future<List<MediaResponse>> listMedia({required List<String> ids}) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.media.list,
      queryParameters: MediaListRequest(ids: ids).toJson(),
    );
    final items = response.data!['items'] as List<dynamic>;
    return items.map((item) => MediaResponse.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<MediaResponse> uploadMedia({
    required String filePath,
    required String originalFilename,
    required String contentType,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(
        filePath,
        filename: originalFilename,
        contentType: dio.DioMediaType.parse(contentType),
      ),
    });
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiEndpoints.media.list,
      data: formData,
      onSendProgress: onSendProgress,
    );
    return MediaResponse.fromJson(response.data!);
  }

  @override
  Future<void> deleteMedia(String id) => _dioClient.delete<void>(ApiEndpoints.media.byId(id));
}
