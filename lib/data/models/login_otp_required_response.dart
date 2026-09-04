import 'package:json_annotation/json_annotation.dart';

part 'login_otp_required_response.g.dart';

@JsonSerializable()
final class LoginOtpRequiredResponse {
  const LoginOtpRequiredResponse({required this.challengeToken, required this.expiresAt});

  factory LoginOtpRequiredResponse.fromJson(Map<String, dynamic> json) => _$LoginOtpRequiredResponseFromJson(json);

  @JsonKey(name: 'challenge_token')
  final String challengeToken;

  @JsonKey(name: 'expires_at')
  final int expiresAt;

  Map<String, dynamic> toJson() => _$LoginOtpRequiredResponseToJson(this);
}
