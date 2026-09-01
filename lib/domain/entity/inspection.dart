import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/domain/enum/inspection_sync_status.dart';
import 'package:beebase/domain/enum/inspection_type.dart';

final class Inspection {
  const Inspection({
    required this.id,
    required this.hiveId,
    required this.date,
    required this.type,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = InspectionSyncStatus.synced,
  });

  final String id;

  /// The hive this inspection belongs to. An inspection is never shown or
  /// acted on outside the context of its hive — every reader/writer call is
  /// scoped by this id, never by [id] alone.
  final String hiveId;

  final DateTime date;
  final InspectionType type;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final InspectionSyncStatus syncStatus;

  /// Whether this inspection was created while offline and has never reached
  /// the server yet — the only data that stays freely deletable while
  /// offline (see `InspectionRepositoryImpl.deleteInspection`).
  bool get isLocalOnly => LocalIdGenerator.isLocal(id);

  Inspection copyWith({InspectionSyncStatus? syncStatus}) {
    return Inspection(
      id: id,
      hiveId: hiveId,
      date: date,
      type: type,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
          other.syncStatus == syncStatus);

  @override
  int get hashCode => Object.hash(id, hiveId, date, type, notes, createdAt, updatedAt, syncStatus);
}
