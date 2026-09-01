import 'package:json_annotation/json_annotation.dart';

part 'refresh_token_response.g.dart';

@JsonSerializable()
final class RefreshTokenResponse {
  const RefreshTokenResponse({required this.accessToken});

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) => _$RefreshTokenResponseFromJson(json);

  @JsonKey(name: 'access_token')
  final String? accessToken;

  Map<String, dynamic> toJson() => _$RefreshTokenResponseToJson(this);
}
