// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserResponse _$UserResponseFromJson(Map<String, dynamic> json) => UserResponse(
  id: json['id'] as String,
  email: json['email'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  avatar: json['avatar'] as String?,
  avatarLocalFilePath: json['avatar_local_file_path'] as String?,
);

Map<String, dynamic> _$UserResponseToJson(UserResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'created_at': instance.createdAt.toIso8601String(),
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'avatar': instance.avatar,
      'avatar_local_file_path': instance.avatarLocalFilePath,
    };
