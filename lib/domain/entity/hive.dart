import 'package:beebase/domain/enum/sync_status.dart';

final class Hive {
  const Hive({
    required this.id,
    required this.apiaryId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.localId,
    this.serverId,
    this.apiaryLocalId,
    this.apiaryServerId,
    this.syncStatus = SyncStatus.synced,
  });

  final String id;

  /// The apiary this hive belongs to. A hive is never shown or acted on
  /// outside the context of its apiary — every reader/writer call is scoped
  /// by this id, never by [id] alone. Mirrors [id]: the server id once the
  /// parent apiary is synced, otherwise the parent's local id.
  final String apiaryId;

  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Media ids currently attached to this hive — hive-service's own source
  /// of truth (see `HiveResponse.images`), not something media-service is
  /// asked about anymore.
  final List<String> images;

  /// Local identifier used in SQLite and offline operations.
  final String? localId;

  /// Backend identifier assigned after successful sync with hive-service.
  final String? serverId;

  /// Local id of the owning apiary, set when this hive was created/last
  /// saved while its apiary had no [Apiary.serverId] yet. Used by
  /// [HiveSynchronizer] to resolve [apiaryServerId] once that apiary syncs —
  /// never sent to the backend directly.
  final String? apiaryLocalId;

  /// Backend id of the owning apiary, once known. A hive can only be
  /// synchronized after this is resolved (see [HiveSynchronizer]).
  final String? apiaryServerId;

  /// Synchronization status of this hive.
  final SyncStatus syncStatus;

  /// Whether this hive already has a counterpart on the backend. Hives
  /// created offline stay [SyncStatus.pendingCreate] until their first
  /// successful sync, so they exist only in SQLite; every other status means
  /// the record was created online and the server owns it too.
  bool get existsOnServer => syncStatus != SyncStatus.pendingCreate;

  Hive copyWith({
    String? id,
    String? apiaryId,
    String? name,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    String? localId,
    String? serverId,
    String? apiaryLocalId,
    String? apiaryServerId,
    SyncStatus? syncStatus,
  }) {
    return Hive(
      id: id ?? this.id,
      apiaryId: apiaryId ?? this.apiaryId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      apiaryLocalId: apiaryLocalId ?? this.apiaryLocalId,
      apiaryServerId: apiaryServerId ?? this.apiaryServerId,
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
          other.localId == localId &&
          other.serverId == serverId &&
          other.apiaryLocalId == apiaryLocalId &&
          other.apiaryServerId == apiaryServerId &&
          other.syncStatus == syncStatus &&
          _listEquals(other.images, images));

  @override
  int get hashCode => Object.hash(
    id,
    apiaryId,
    name,
    notes,
    createdAt,
    updatedAt,
    localId,
    serverId,
    apiaryLocalId,
    apiaryServerId,
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
