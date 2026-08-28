import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:dio/dio.dart' as dio;

final class ApiaryDataSource implements IApiaryDataSource {
  ApiaryDataSource({required DioClient dioClient, required InterceptorResolver resolver})
    : _dioClient = dioClient.copyWith(
        interceptors: [resolver.resolve<AuthenticationInterceptor>(), dio.LogInterceptor(requestBody: true, responseBody: true)],
      );

  final DioClient _dioClient;

  @override
  Future<List<ApiaryResponse>> getApiaries() async {
    final response = await _dioClient.get<List<dynamic>>(ApiEndpoints.apiaries.list);
    return (response.data ?? const []).map((json) => ApiaryResponse.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<ApiaryResponse> getApiary(String id) async {
    final response = await _dioClient.get<Map<String, dynamic>>(ApiEndpoints.apiaries.byId(id));
    return ApiaryResponse.fromJson(response.data!);
  }

  @override
  Future<ApiaryResponse> createApiary(ApiaryRequest request, {String? idempotencyKey}) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiEndpoints.apiaries.list,
      data: request.toJson(),
      headers: idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
    );
    return ApiaryResponse.fromJson(response.data!);
  }

  @override
  Future<ApiaryResponse> updateApiary(String id, ApiaryRequest request) async {
    final response = await _dioClient.put<Map<String, dynamic>>(ApiEndpoints.apiaries.byId(id), data: request.toJson());
    return ApiaryResponse.fromJson(response.data!);
  }

  @override
  Future<void> deleteApiary(String id) => _dioClient.delete<void>(ApiEndpoints.apiaries.byId(id));
}
