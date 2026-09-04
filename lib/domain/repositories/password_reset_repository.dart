import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/password_reset_flow.dart';
import 'package:beebase/domain/entity/password_reset_verification.dart';
import 'package:beebase/utils/either.dart';

/// The forgot-password flow: `Email submitted → OTP verified → Password
/// reset`. The OTP step can never be skipped — `confirmPasswordReset`
/// requires a `resetToken` that only `verifyPasswordResetOtp` can issue.
abstract interface class IPasswordResetFlow {
  Future<Either<Failure, PasswordResetFlow>> requestPasswordReset({required String email});

  Future<Either<Failure, PasswordResetVerification>> verifyPasswordResetOtp({
    required String flowToken,
    required String otp,
  });

  Future<Either<Failure, void>> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  });
}
