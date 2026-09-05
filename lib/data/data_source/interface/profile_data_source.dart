import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';

abstract interface class IProfileDataSource {
  Future<ProfileResponse> getProfile();

  Future<ProfileResponse> updateProfile(ProfileUpdateRequest request);

  /// `DELETE /api/v1/profile` — permanently deletes the authenticated
  /// user's account and everything it owns. [otp] must be a currently
  /// valid TOTP code; the backend rejects the request (and deletes
  /// nothing) if it isn't.
  Future<void> deleteAccount({required String otp});
}
