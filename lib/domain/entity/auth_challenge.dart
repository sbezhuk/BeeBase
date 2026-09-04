part 'totp_setup_challenge.dart';
part 'login_otp_challenge.dart';

/// What `AuthenticationRepository.login`/`.register` return instead of a
/// session — credentials alone are never enough, a TOTP code must also be
/// verified (via `AuthenticationRepository.verifyTotpSetup`/
/// `.verifyLoginOtp`) before a [User] session is issued.
sealed class AuthChallenge {
  const AuthChallenge();
}
