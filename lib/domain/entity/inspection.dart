import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';

final class Inspection {
  const Inspection({
    required this.id,
    required this.hiveId,
    required this.date,
    required this.type,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.localId,
    this.serverId,
    this.hiveLocalId,
    this.hiveServerId,
    this.syncStatus = SyncStatus.synced,
  });

  final String id;

  /// The hive this inspection belongs to. An inspection is never shown or
  /// acted on outside the context of its hive — every reader/writer call is
  /// scoped by this id, never by [id] alone. Mirrors [id]: the server id
  /// once the parent hive is synced, otherwise the parent's local id.
  final String hiveId;

  final DateTime date;
  final InspectionType type;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Media ids currently attached to this inspection — inspection-service's
  /// own source of truth (see `InspectionResponse.images`), not something
  /// media-service is asked about anymore.
  final List<String> images;

  /// Local identifier used in SQLite and offline operations.
  final String? localId;

  /// Backend identifier assigned after successful sync with
  /// inspection-service.
  final String? serverId;

  /// Local id of the owning hive, set when this inspection was
  /// created/last saved while its hive had no [Hive.serverId] yet. Used by
  /// `InspectionSynchronizer` to resolve [hiveServerId] once that hive
  /// syncs — never sent to the backend directly.
  final String? hiveLocalId;

  /// Backend id of the owning hive, once known. An inspection can only be
  /// synchronized after this is resolved (see `InspectionSynchronizer`).
  final String? hiveServerId;

  /// Synchronization status of this inspection.
  final SyncStatus syncStatus;

  /// Whether this inspection already has a counterpart on the backend.
  /// Inspections created offline stay [SyncStatus.pendingCreate] until
  /// their first successful sync, so they exist only in SQLite; every other
  /// status means the record was created online and the server owns it too.
  bool get existsOnServer => syncStatus != SyncStatus.pendingCreate;

  Inspection copyWith({
    String? id,
    String? hiveId,
    DateTime? date,
    InspectionType? type,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    String? localId,
    String? serverId,
    String? hiveLocalId,
    String? hiveServerId,
    SyncStatus? syncStatus,
  }) {
    return Inspection(
      id: id ?? this.id,
      hiveId: hiveId ?? this.hiveId,
      date: date ?? this.date,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      hiveLocalId: hiveLocalId ?? this.hiveLocalId,
      hiveServerId: hiveServerId ?? this.hiveServerId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Inspection &&
          other.id == id &&
          other.hiveId == hiveId &&
          other.date == date &&
          other.type == type &&
          other.notes == notes &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.localId == localId &&
          other.serverId == serverId &&
          other.hiveLocalId == hiveLocalId &&
          other.hiveServerId == hiveServerId &&
          other.syncStatus == syncStatus &&
          _listEquals(other.images, images));

  @override
  int get hashCode => Object.hash(
    id,
    hiveId,
    date,
    type,
    notes,
    createdAt,
    updatedAt,
    localId,
    serverId,
    hiveLocalId,
    hiveServerId,
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
