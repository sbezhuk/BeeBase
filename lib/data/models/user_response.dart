import 'package:json_annotation/json_annotation.dart';

part 'user_response.g.dart';

@JsonSerializable()
final class UserResponse {
  const UserResponse({
    required this.id,
    required this.email,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.avatar,
    this.avatarLocalFilePath,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) =>
      _$UserResponseFromJson(json);

  final String id;
  final String email;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'first_name')
  final String? firstName;

  @JsonKey(name: 'last_name')
  final String? lastName;

  /// The avatar media id, or `null` if this user has no avatar set.
  final String? avatar;

  /// Local-only, never present in the server's JSON — mirrors
  /// `MediaResponse.localFilePath`: either a not-yet-uploaded avatar pick
  /// (while [avatar] is still a local placeholder id) or a downloaded
  /// render-cache copy of an already-synced avatar. Persisted across the
  /// cached round trip ([toJson]/[fromJson]) exactly like every other field
  /// here, since this DTO is what `LocalDataSource<UserResponse>` stores —
  /// only never sent to the server.
  @JsonKey(name: 'avatar_local_file_path')
  final String? avatarLocalFilePath;

  Map<String, dynamic> toJson() => _$UserResponseToJson(this);

  UserResponse copyWith({
    String? firstName,
    String? lastName,
    String? avatar,
    bool clearAvatar = false,
    String? avatarLocalFilePath,
    bool clearAvatarLocalFilePath = false,
  }) {
    return UserResponse(
      id: id,
      email: email,
      createdAt: createdAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
      avatarLocalFilePath: clearAvatarLocalFilePath
          ? null
          : (avatarLocalFilePath ?? this.avatarLocalFilePath),
    );
  }
}
