import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/models/user_response.dart';

final class ProfileDataSource implements IProfileDataSource {
  ProfileDataSource({
    required DioClient dioClient,
    required InterceptorResolver resolver,
  }) : _dioClient = dioClient.copyWith(
         interceptors: [resolver.resolve<AuthenticationInterceptor>()],
       );

  final DioClient _dioClient;

  @override
  Future<UserResponse> getProfile() async {
    final response = await _dioClient.get<Map<String, dynamic>>(
      ApiEndpoints.profile.self,
    );
    return UserResponse.fromJson(response.data!);
  }

  @override
  Future<UserResponse> updateProfile(ProfileUpdateRequest request) async {
    final response = await _dioClient.put<Map<String, dynamic>>(
      ApiEndpoints.profile.self,
      data: request.toJson(),
    );
    return UserResponse.fromJson(response.data!);
  }
}
