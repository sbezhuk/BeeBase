import 'package:json_annotation/json_annotation.dart';

part 'password_reset_otp_verified_response.g.dart';

@JsonSerializable()
final class PasswordResetOtpVerifiedResponse {
  const PasswordResetOtpVerifiedResponse({required this.resetToken, required this.expiresAt});

  factory PasswordResetOtpVerifiedResponse.fromJson(Map<String, dynamic> json) =>
      _$PasswordResetOtpVerifiedResponseFromJson(json);

  @JsonKey(name: 'reset_token')
  final String resetToken;

  @JsonKey(name: 'expires_at')
  final int expiresAt;

  Map<String, dynamic> toJson() => _$PasswordResetOtpVerifiedResponseToJson(this);
}
