final class Apiary {
  const Apiary({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.lat,
    this.lon,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? location;
  final double? lat;
  final double? lon;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Media ids currently attached to this apiary — apiary-service's own
  /// source of truth (see `ApiaryResponse.images`), not something media-
  /// service is asked about anymore.
  final List<String> images;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Apiary &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.location == location &&
          other.lat == lat &&
          other.lon == lon &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          _listEquals(other.images, images));

  @override
  int get hashCode =>
      Object.hash(id, name, description, location, lat, lon, createdAt, updatedAt, Object.hashAll(images));
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
