import 'package:json_annotation/json_annotation.dart';

part 'login_verify_otp_request.g.dart';

@JsonSerializable()
final class LoginVerifyOtpRequest {
  const LoginVerifyOtpRequest({required this.challengeToken, required this.otp});

  factory LoginVerifyOtpRequest.fromJson(Map<String, dynamic> json) => _$LoginVerifyOtpRequestFromJson(json);

  @JsonKey(name: 'challenge_token')
  final String challengeToken;

  final String otp;

  Map<String, dynamic> toJson() => _$LoginVerifyOtpRequestToJson(this);
}
