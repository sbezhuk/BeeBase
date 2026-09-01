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
          other.syncStatus == syncStatus);

  @override
  int get hashCode => Object.hash(id, name, description, location, lat, lon, createdAt, updatedAt, syncStatus);
}
