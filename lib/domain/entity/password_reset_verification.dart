/// Issued by `AuthenticationRepository.verifyPasswordResetOtp` on a
/// successful OTP check. [resetToken] is single-use and required by
/// `.confirmPasswordReset` — the OTP step can't be skipped, since a flow
/// with no verified OTP never has a [resetToken] to present.
final class PasswordResetVerification {
  const PasswordResetVerification({required this.resetToken, required this.expiresAt});

  final String resetToken;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasswordResetVerification && other.resetToken == resetToken && other.expiresAt == expiresAt);

  @override
  int get hashCode => Object.hash(resetToken, expiresAt);
}
