import 'package:beebase/data/models/user_response.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_response.g.dart';

@JsonSerializable()
final class SessionResponse {
  const SessionResponse({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) => _$SessionResponseFromJson(json);

  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'access_token_expires_at')
  final int accessTokenExpiresAt;

  @JsonKey(name: 'refresh_token_expires_at')
  final int refreshTokenExpiresAt;

  final UserResponse user;

  Map<String, dynamic> toJson() => _$SessionResponseToJson(this);
}
