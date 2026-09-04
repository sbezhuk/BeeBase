import 'package:json_annotation/json_annotation.dart';

part 'setup_verify_request.g.dart';

@JsonSerializable()
final class SetupVerifyRequest {
  const SetupVerifyRequest({required this.setupToken, required this.otp});

  factory SetupVerifyRequest.fromJson(Map<String, dynamic> json) => _$SetupVerifyRequestFromJson(json);

  @JsonKey(name: 'setup_token')
  final String setupToken;

  final String otp;

  Map<String, dynamic> toJson() => _$SetupVerifyRequestToJson(this);
}
