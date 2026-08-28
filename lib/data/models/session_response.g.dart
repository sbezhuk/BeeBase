// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionResponse _$SessionResponseFromJson(Map<String, dynamic> json) => SessionResponse(
  accessToken: json['access_token'] as String,
  accessTokenExpiresAt: (json['access_token_expires_at'] as num).toInt(),
  refreshTokenExpiresAt: (json['refresh_token_expires_at'] as num).toInt(),
  user: UserResponse.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SessionResponseToJson(SessionResponse instance) => <String, dynamic>{
  'access_token': instance.accessToken,
  'access_token_expires_at': instance.accessTokenExpiresAt,
  'refresh_token_expires_at': instance.refreshTokenExpiresAt,
  'user': instance.user,
};
