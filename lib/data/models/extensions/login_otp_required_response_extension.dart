import 'package:beebase/data/models/login_otp_required_response.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';

extension LoginOtpRequiredResponseX on LoginOtpRequiredResponse {
  LoginOtpChallenge toEntity() => LoginOtpChallenge(
    challengeToken: challengeToken,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
  );
}
