part of 'auth_challenge.dart';

/// Issued by login when the account already has 2FA enabled. Resolve with
/// `AuthenticationRepository.verifyLoginOtp`.
final class LoginOtpChallenge extends AuthChallenge {
  const LoginOtpChallenge({required this.challengeToken, required this.expiresAt});

  final String challengeToken;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoginOtpChallenge && other.challengeToken == challengeToken && other.expiresAt == expiresAt);

  @override
  int get hashCode => Object.hash(challengeToken, expiresAt);
}
