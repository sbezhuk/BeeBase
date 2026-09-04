import 'package:beebase/data/models/totp_setup_response.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';

extension TotpSetupResponseX on TotpSetupResponse {
  TotpSetupChallenge toEntity() => TotpSetupChallenge(
    setupToken: setupToken,
    otpauthUri: otpauthUri,
    secret: secret,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
  );
}
