import 'package:beebase/domain/entity/user.dart';

/// The editable subset of a user's account — `GET`/`PUT /api/v1/profile`'s
/// own resource, distinct from `User` (`/api/v1/auth/me`'s resource): it
/// has no `createdAt` of its own, so `ProfileCubit`/`ProfileEditCubit` merge
/// this onto the already-known `User` (see [mergeOnto]) rather than
/// treating it as a full replacement.
final class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarId,
    this.avatarLocalFilePath,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// The avatar media id, or `null` if this user has no avatar set.
  final String? avatarId;

  /// Local-only render cache for [avatarId]'s bytes — either a not-yet
  /// uploaded pick or a downloaded copy of an already-synced avatar. Never
  /// sent to the server.
  final String? avatarLocalFilePath;

  /// Merges this profile's fields onto [user] — the counterpart of
  /// [User.copyWith] that `ProfileCubit`/`ProfileEditCubit` call after a
  /// successful fetch/edit, since this resource carries no `createdAt` of
  /// its own to build a full [User] from directly.
  User mergeOnto(User user) => user.copyWith(
    firstName: firstName,
    lastName: lastName,
    avatarId: avatarId,
    clearAvatarId: avatarId == null,
    avatarLocalFilePath: avatarLocalFilePath,
    clearAvatarLocalFilePath: avatarLocalFilePath == null,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Profile &&
          other.id == id &&
          other.email == email &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.avatarId == avatarId &&
          other.avatarLocalFilePath == avatarLocalFilePath);

  @override
  int get hashCode => Object.hash(id, email, firstName, lastName, avatarId, avatarLocalFilePath);
}
