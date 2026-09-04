final class Hive {
  const Hive({
    required this.id,
    required this.apiaryId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  final String id;

  /// The apiary this hive belongs to. A hive is never shown or acted on
  /// outside the context of its apiary — every reader/writer call is scoped
  /// by this id, never by [id] alone.
  final String apiaryId;

  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Media ids currently attached to this hive — hive-service's own source
  /// of truth (see `HiveResponse.images`), not something media-service is
  /// asked about anymore.
  final List<String> images;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Hive &&
          other.id == id &&
          other.apiaryId == apiaryId &&
          other.name == name &&
          other.notes == notes &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          _listEquals(other.images, images));

  @override
  int get hashCode =>
      Object.hash(id, apiaryId, name, notes, createdAt, updatedAt, Object.hashAll(images));
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
