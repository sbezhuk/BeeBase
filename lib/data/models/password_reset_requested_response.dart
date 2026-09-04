import 'package:json_annotation/json_annotation.dart';

part 'password_reset_requested_response.g.dart';

@JsonSerializable()
final class PasswordResetRequestedResponse {
  const PasswordResetRequestedResponse({required this.flowToken, required this.expiresAt});

  factory PasswordResetRequestedResponse.fromJson(Map<String, dynamic> json) =>
      _$PasswordResetRequestedResponseFromJson(json);

  @JsonKey(name: 'flow_token')
  final String flowToken;

  @JsonKey(name: 'expires_at')
  final int expiresAt;

  Map<String, dynamic> toJson() => _$PasswordResetRequestedResponseToJson(this);
}
