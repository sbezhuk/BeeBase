/// Issued by `AuthenticationRepository.requestPasswordReset`. Not, by
/// itself, sufficient to reset anything — [flowToken] must still be
/// verified against a TOTP code via `.verifyPasswordResetOtp`.
final class PasswordResetFlow {
  const PasswordResetFlow({required this.flowToken, required this.expiresAt});

  final String flowToken;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PasswordResetFlow && other.flowToken == flowToken && other.expiresAt == expiresAt);

  @override
  int get hashCode => Object.hash(flowToken, expiresAt);
}
