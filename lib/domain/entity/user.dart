final class User {
  const User({
    required this.id,
    required this.email,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.avatarId,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final String? firstName;
  final String? lastName;

  /// The media id of this user's avatar, or `null` if none is set.
  final String? avatarId;

  /// Merges freshly fetched/edited profile fields (see `Profile`) onto this
  /// user — used by `ProfileCubit`/`ProfileEditCubit` to update
  /// `AuthenticationCubit`'s single source of truth without losing [id]/
  /// [email]/[createdAt], none of which the profile resource itself carries.
  User copyWith({
    String? firstName,
    String? lastName,
    String? avatarId,
    bool clearAvatarId = false,
  }) {
    return User(
      id: id,
      email: email,
      createdAt: createdAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarId: clearAvatarId ? null : (avatarId ?? this.avatarId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.createdAt == createdAt &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.avatarId == avatarId);

  @override
  int get hashCode => Object.hash(id, email, createdAt, firstName, lastName, avatarId);
}
