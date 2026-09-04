part of 'auth_challenge.dart';

/// Issued by registration, and by login when an account never completed
/// TOTP setup. [secret]/[otpauthUri] are only ever exposed at this point —
/// resolve with `AuthenticationRepository.verifyTotpSetup`.
final class TotpSetupChallenge extends AuthChallenge {
  const TotpSetupChallenge({
    required this.setupToken,
    required this.otpauthUri,
    required this.secret,
    required this.expiresAt,
  });

  final String setupToken;
  final String otpauthUri;
  final String secret;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TotpSetupChallenge &&
          other.setupToken == setupToken &&
          other.otpauthUri == otpauthUri &&
          other.secret == secret &&
          other.expiresAt == expiresAt);

  @override
  int get hashCode => Object.hash(setupToken, otpauthUri, secret, expiresAt);
}
