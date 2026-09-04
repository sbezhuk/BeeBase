import 'package:beebase/data/models/password_reset_otp_verified_response.dart';
import 'package:beebase/data/models/password_reset_requested_response.dart';

abstract interface class IPasswordResetDataSource {
  Future<PasswordResetRequestedResponse> requestPasswordReset({required String email});

  Future<PasswordResetOtpVerifiedResponse> verifyPasswordResetOtp({required String flowToken, required String otp});

  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  });
}
