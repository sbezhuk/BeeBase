import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';

abstract interface class IProfileDataSource {
  Future<ProfileResponse> getProfile();

  Future<ProfileResponse> updateProfile(ProfileUpdateRequest request);
}
