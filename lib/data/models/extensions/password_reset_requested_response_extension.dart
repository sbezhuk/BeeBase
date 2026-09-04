import 'package:beebase/data/models/password_reset_requested_response.dart';
import 'package:beebase/domain/entity/password_reset_flow.dart';

extension PasswordResetRequestedResponseX on PasswordResetRequestedResponse {
  PasswordResetFlow toEntity() => PasswordResetFlow(
    flowToken: flowToken,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
  );
}
