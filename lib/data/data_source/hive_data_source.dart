import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/idempotency_key_header.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';

final class HiveDataSource implements IHiveDataSource {
  HiveDataSource({
    required DioClient dioClient,
    required InterceptorResolver resolver,
  }) : _dioClient = dioClient.copyWith(
         interceptors: [resolver.resolve<AuthenticationInterceptor>()],
       );

  final DioClient _dioClient;

  @override
  Future<PaginatedResponse<HiveResponse>> getHives(PageRequest request) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.hives.list,
      queryParameters: request.toJson(),
    );
    return PaginatedResponse.fromJson(
      response.data!,
      (json) => HiveResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<HiveResponse> getHive(String id) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.hives.byId(id),
    );
    return HiveResponse.fromJson(response.data!);
  }

  /// [apiaryId] is merged into the body as `apiary_id` here rather than
  /// being a field on [HiveRequest] — it's only present on
  /// `CreateHiveRequest`, not `UpdateHiveRequest`, and [HiveRequest] is
  /// shared by both.
  @override
  Future<HiveResponse> createHive(
    HiveRequest request, {
    required String apiaryId,
    String? idempotencyKey,
  }) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiEndpoints.hives.list,
      data: {'apiary_id': apiaryId, ...request.toJson()},
      headers: idempotencyKey == null
          ? null
          : IdempotencyKeyHeader(idempotencyKey: idempotencyKey).toJson(),
    );
    return HiveResponse.fromJson(response.data!);
  }

  @override
  Future<HiveResponse> updateHive(String id, HiveRequest request) async {
    final response = await _dioClient.put<Map<String, dynamic>>(
      ApiEndpoints.hives.byId(id),
      data: request.toJson(),
    );
    return HiveResponse.fromJson(response.data!);
  }

  @override
  Future<void> deleteHive(String id) =>
      _dioClient.delete<void>(ApiEndpoints.hives.byId(id));
}
