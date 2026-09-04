import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';

final class InspectionDataSource implements IInspectionDataSource {
  InspectionDataSource({required DioClient dioClient, required InterceptorResolver resolver})
    : _dioClient = dioClient.copyWith(
        interceptors: [resolver.resolve<AuthenticationInterceptor>()],
      );

  final DioClient _dioClient;

  @override
  Future<PaginatedResponse<InspectionResponse>> getInspections(
    String hiveId,
    PageRequest request,
  ) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.inspections.list(hiveId),
      queryParameters: request.toJson(),
    );
    return PaginatedResponse.fromJson(
      response.data!,
      (json) => InspectionResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// [hiveId] is accepted (unused here) purely so callers — which only ever
  /// hold an inspection in the context of its hive — don't need a separate
  /// hiveId-less code path; inspection-service's single-item routes are
  /// flat (`/api/v1/inspections/{id}`), never nested under a hive.
  @override
  Future<InspectionResponse> getInspection(String hiveId, String id) async {
    final response = await _dioClient.get<Map<String, dynamic>>(ApiEndpoints.inspections.byId(id));
    return InspectionResponse.fromJson(response.data!);
  }

  /// [hiveId] is merged into the body as `hive_id` here rather than being a
  /// field on [InspectionRequest] — it's only present on inspection-service's
  /// `CreateRequest`, not its `UpdateRequest`, and [InspectionRequest] is
  /// shared by both. Mirrors [HiveDataSource.createHive].
  @override
  Future<InspectionResponse> createInspection(
    String hiveId,
    InspectionRequest request,
  ) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      ApiEndpoints.inspections.create(),
      data: {'hive_id': hiveId, ...request.toJson()},
    );
    return InspectionResponse.fromJson(response.data!);
  }

  /// See [getInspection] on why [hiveId] goes unused.
  @override
  Future<InspectionResponse> updateInspection(
    String hiveId,
    String id,
    InspectionRequest request,
  ) async {
    final response = await _dioClient.put<Map<String, dynamic>>(
      ApiEndpoints.inspections.byId(id),
      data: request.toJson(),
    );
    return InspectionResponse.fromJson(response.data!);
  }

  /// See [getInspection] on why [hiveId] goes unused.
  @override
  Future<void> deleteInspection(String hiveId, String id) =>
      _dioClient.delete<void>(ApiEndpoints.inspections.byId(id));
}
