import 'package:json_annotation/json_annotation.dart';

part 'password_reset_confirm_request.g.dart';

@JsonSerializable()
final class PasswordResetConfirmRequest {
  const PasswordResetConfirmRequest({
    required this.resetToken,
    required this.newPassword,
    required this.confirmPassword,
  });

  factory PasswordResetConfirmRequest.fromJson(Map<String, dynamic> json) =>
      _$PasswordResetConfirmRequestFromJson(json);

  @JsonKey(name: 'reset_token')
  final String resetToken;

  @JsonKey(name: 'new_password')
  final String newPassword;

  @JsonKey(name: 'confirm_password')
  final String confirmPassword;

  Map<String, dynamic> toJson() => _$PasswordResetConfirmRequestToJson(this);
}
