import 'package:beebase/core/networking/api_endpoints.dart';
import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/delete_account_request.dart';
import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';

final class ProfileDataSource implements IProfileDataSource {
  ProfileDataSource({required DioClient dioClient, required InterceptorResolver resolver})
    : _dioClient = dioClient.copyWith(interceptors: [resolver.resolve<AuthenticationInterceptor>()]);

  final DioClient _dioClient;

  @override
  Future<ProfileResponse> getProfile() async {
    final response = await _dioClient.get<Map<String, dynamic>>(ApiEndpoints.profile.self);
    return ProfileResponse.fromJson(response.data!);
  }

  @override
  Future<ProfileResponse> updateProfile(ProfileUpdateRequest request) async {
    final response = await _dioClient.put<Map<String, dynamic>>(ApiEndpoints.profile.self, data: request.toJson());
    return ProfileResponse.fromJson(response.data!);
  }

  @override
  Future<void> deleteAccount({required String otp}) =>
      _dioClient.delete<void>(ApiEndpoints.profile.self, data: DeleteAccountRequest(otp: otp).toJson());
}
