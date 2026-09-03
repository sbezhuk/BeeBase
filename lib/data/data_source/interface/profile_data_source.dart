import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/models/user_response.dart';

abstract interface class IProfileDataSource {
  Future<UserResponse> getProfile();

  Future<UserResponse> updateProfile(ProfileUpdateRequest request);
}
