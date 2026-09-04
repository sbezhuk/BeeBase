import 'package:beebase/data/models/password_reset_otp_verified_response.dart';
import 'package:beebase/domain/entity/password_reset_verification.dart';

extension PasswordResetOtpVerifiedResponseX on PasswordResetOtpVerifiedResponse {
  PasswordResetVerification toEntity() => PasswordResetVerification(
    resetToken: resetToken,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
  );
}
