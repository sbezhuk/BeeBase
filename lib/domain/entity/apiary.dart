import 'package:beebase/domain/enum/sync_status.dart';

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
    this.localId,
    this.serverId,
    this.syncStatus = SyncStatus.synced,
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

  /// Local identifier used in SQLite and offline operations.
  final String? localId;

  /// Backend identifier assigned after successful sync with apiary-service.
  final String? serverId;

  /// Synchronization status of this apiary.
  final SyncStatus syncStatus;

  /// Whether this apiary already has a counterpart on the backend. Apiaries
  /// created offline stay [SyncStatus.pendingCreate] until their first
  /// successful sync, so they exist only in SQLite; every other status means
  /// the record was created online and the server owns it too.
  bool get existsOnServer => syncStatus != SyncStatus.pendingCreate;

  Apiary copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    double? lat,
    double? lon,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    String? localId,
    String? serverId,
    SyncStatus? syncStatus,
  }) {
    return Apiary(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
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
          other.localId == localId &&
          other.serverId == serverId &&
          other.syncStatus == syncStatus &&
          _listEquals(other.images, images));

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        location,
        lat,
        lon,
        createdAt,
        updatedAt,
        localId,
        serverId,
        syncStatus,
        Object.hashAll(images),
      );
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
