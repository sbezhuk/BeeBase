import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/domain/enum/local/hive_sync_status.dart';

final class Hive {
  const Hive({
    required this.id,
    required this.apiaryId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.syncStatus = HiveSyncStatus.synced,
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
  /// asked about anymore. Only as fresh as the last fetch/cache read that
  /// produced this instance.
  final List<String> images;

  final HiveSyncStatus syncStatus;

  /// Whether this hive was created while offline and has never reached the
  /// server yet — the only data that stays freely deletable while offline
  /// (see `HiveRepositoryImpl.deleteHive`).
  bool get isLocalOnly => LocalIdGenerator.isLocal(id);

  Hive copyWith({HiveSyncStatus? syncStatus}) {
    return Hive(
      id: id,
      apiaryId: apiaryId,
      name: name,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      images: images,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

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
          _listEquals(other.images, images) &&
          other.syncStatus == syncStatus);

  @override
  int get hashCode =>
      Object.hash(id, apiaryId, name, notes, createdAt, updatedAt, Object.hashAll(images), syncStatus);
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
