import 'package:json_annotation/json_annotation.dart';

part 'totp_setup_response.g.dart';

@JsonSerializable()
final class TotpSetupResponse {
  const TotpSetupResponse({
    required this.setupToken,
    required this.otpauthUri,
    required this.secret,
    required this.expiresAt,
  });

  factory TotpSetupResponse.fromJson(Map<String, dynamic> json) => _$TotpSetupResponseFromJson(json);

  @JsonKey(name: 'setup_token')
  final String setupToken;

  @JsonKey(name: 'otpauth_uri')
  final String otpauthUri;

  final String secret;

  @JsonKey(name: 'expires_at')
  final int expiresAt;

  Map<String, dynamic> toJson() => _$TotpSetupResponseToJson(this);
}
