final class User {
  const User({
    required this.id,
    required this.email,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.avatarId,
    this.avatarLocalFilePath,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final String? firstName;
  final String? lastName;

  /// The media id of this user's avatar, or `null` if none is set. A
  /// [avatarId] starting with `local-` (see `LocalIdGenerator`) means the
  /// avatar was picked while offline and hasn't uploaded yet.
  final String? avatarId;

  /// Local-only render cache for [avatarId]'s bytes — either a not-yet
  /// synced pick or a downloaded copy of an already-synced avatar. Never
  /// sent to the server. `null` means nothing is cached locally yet.
  final String? avatarLocalFilePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.createdAt == createdAt &&
          other.firstName == firstName &&
          other.lastName == lastName &&
          other.avatarId == avatarId &&
          other.avatarLocalFilePath == avatarLocalFilePath);

  @override
  int get hashCode => Object.hash(
    id,
    email,
    createdAt,
    firstName,
    lastName,
    avatarId,
    avatarLocalFilePath,
  );
}
