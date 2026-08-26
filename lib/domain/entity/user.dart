final class User {
  const User({required this.id, required this.email, required this.createdAt});

  final String id;
  final String email;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(id, email, createdAt);
}
