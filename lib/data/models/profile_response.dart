import 'package:json_annotation/json_annotation.dart';

part 'profile_response.g.dart';

/// `GET`/`PUT /api/v1/profile`'s own resource — camelCase on the wire
/// (unlike every other BeeBase service) and, notably, no `createdAt`; see
/// `Profile`/`User.copyWith` for how that's reconciled.
@JsonSerializable()
final class ProfileResponse {
  const ProfileResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatar,
    this.avatarLocalFilePath,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) => _$ProfileResponseFromJson(json);

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// The avatar media id, or `null` if this user has no avatar set.
  final String? avatar;

  /// Local-only, never present in the server's JSON — mirrors
  /// `MediaResponse.localFilePath`: either a not-yet-uploaded avatar pick or
  /// a downloaded render-cache copy of an already-synced avatar. Persisted
  /// across the cached round trip ([toJson]/[fromJson]) like every other
  /// field here, since this DTO is what `LocalDataSource<ProfileResponse>`
  /// stores — only never sent to the server.
  final String? avatarLocalFilePath;

  Map<String, dynamic> toJson() => _$ProfileResponseToJson(this);

  ProfileResponse copyWith({
    String? firstName,
    String? lastName,
    String? avatar,
    bool clearAvatar = false,
    String? avatarLocalFilePath,
    bool clearAvatarLocalFilePath = false,
  }) {
    return ProfileResponse(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
      avatarLocalFilePath: clearAvatarLocalFilePath ? null : (avatarLocalFilePath ?? this.avatarLocalFilePath),
    );
  }
}
