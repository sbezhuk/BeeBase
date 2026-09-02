import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/domain/enum/local/apiary_sync_status.dart';

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
    this.syncStatus = ApiarySyncStatus.synced,
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
  /// service is asked about anymore. Only as fresh as the last fetch/cache
  /// read that produced this instance.
  final List<String> images;

  final ApiarySyncStatus syncStatus;

  /// Whether this apiary was created while offline and has never reached
  /// the server yet — the only data that stays freely deletable while
  /// offline (see `ApiaryRepositoryImpl.deleteApiary`).
  bool get isLocalOnly => LocalIdGenerator.isLocal(id);

  Apiary copyWith({ApiarySyncStatus? syncStatus}) {
    return Apiary(
      id: id,
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
      createdAt: createdAt,
      updatedAt: updatedAt,
      images: images,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

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
          _listEquals(other.images, images) &&
          other.syncStatus == syncStatus);

  @override
  int get hashCode =>
      Object.hash(id, name, description, location, lat, lon, createdAt, updatedAt, Object.hashAll(images), syncStatus);
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
