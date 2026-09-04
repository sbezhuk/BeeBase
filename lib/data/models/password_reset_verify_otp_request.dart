import 'package:json_annotation/json_annotation.dart';

part 'password_reset_verify_otp_request.g.dart';

@JsonSerializable()
final class PasswordResetVerifyOtpRequest {
  const PasswordResetVerifyOtpRequest({required this.flowToken, required this.otp});

  factory PasswordResetVerifyOtpRequest.fromJson(Map<String, dynamic> json) =>
      _$PasswordResetVerifyOtpRequestFromJson(json);

  @JsonKey(name: 'flow_token')
  final String flowToken;

  final String otp;

  Map<String, dynamic> toJson() => _$PasswordResetVerifyOtpRequestToJson(this);
}
