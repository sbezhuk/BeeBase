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
  });

  final String id;
  final String name;
  final String? description;
  final String? location;
  final double? lat;
  final double? lon;
  final DateTime createdAt;
  final DateTime updatedAt;

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
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(id, name, description, location, lat, lon, createdAt, updatedAt);
}
