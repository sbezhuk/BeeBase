import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/statistics_data_source.dart';
import 'package:beebase/data/models/activity_response.dart';
import 'package:beebase/data/models/apiary_stats_response.dart';
import 'package:beebase/data/models/inspection_stats_response.dart';
import 'package:beebase/data/models/overview_response.dart';
import 'package:dio/dio.dart' as dio;

final class StatisticsDataSource implements IStatisticsDataSource {
  StatisticsDataSource({
    required DioClient dioClient,
    required InterceptorResolver resolver,
  }) : _dioClient = dioClient.copyWith(
         interceptors: [
           resolver.resolve<AuthenticationInterceptor>(),
           dio.LogInterceptor(requestBody: true, responseBody: true),
         ],
       );

  final DioClient _dioClient;

  @override
  Future<OverviewResponse> getOverview() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.statistics.overview,
    );
    return OverviewResponse.fromJson(response.data!);
  }

  @override
  Future<ApiaryStatsResponse> getApiaryStats() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.statistics.apiaries,
    );
    return ApiaryStatsResponse.fromJson(response.data!);
  }

  @override
  Future<InspectionStatsResponse> getInspectionStats() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.statistics.inspections,
    );
    return InspectionStatsResponse.fromJson(response.data!);
  }

  @override
  Future<ActivityResponse> getActivity({int limit = 10}) async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.statistics.activity,
      queryParameters: {'limit': limit},
    );
    return ActivityResponse.fromJson(response.data!);
  }
}
