import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/media_list_request.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/media_upload_form_request.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:dio/dio.dart' as dio;

final class MediaDataSource implements IMediaDataSource {
  MediaDataSource({
    required DioClient dioClient,
    required InterceptorResolver resolver,
  }) : _dioClient = dioClient.copyWith(
         interceptors: [resolver.resolve<AuthenticationInterceptor>()],
       );

  final DioClient _dioClient;

  @override
  Future<PaginatedResponse<MediaResponse>> listMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required PageRequest request,
  }) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.media.list,
      queryParameters: {
        ...MediaListRequest(ownerType: ownerType, ownerId: ownerId).toJson(),
        ...request.toJson(),
      },
    );
    return PaginatedResponse.fromJson(
      response.data!,
      (json) => MediaResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<String> uploadMedia({
    required String filePath,
    required String originalFilename,
    required String contentType,
    String? idempotencyKey,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = dio.FormData.fromMap({
      ...MediaUploadFormRequest(mediaId: idempotencyKey).toJson(),
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
    return response.data!['id'] as String;
  }

  @override
  Future<List<int>> downloadMedia(String id) async {
    final response = await _dioClient.getBytes(ApiEndpoints.media.download(id));
    return response.data!;
  }

  @override
  Future<void> deleteMedia(String id) =>
      _dioClient.delete<void>(ApiEndpoints.media.byId(id));
}
