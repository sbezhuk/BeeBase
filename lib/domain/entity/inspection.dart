import 'package:beebase/domain/enum/backend/inspection_type.dart';

final class Inspection {
  const Inspection({
    required this.id,
    required this.hiveId,
    required this.date,
    required this.type,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// The hive this inspection belongs to. An inspection is never shown or
  /// acted on outside the context of its hive — every reader/writer call is
  /// scoped by this id, never by [id] alone.
  final String hiveId;

  final DateTime date;
  final InspectionType type;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

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
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(id, hiveId, date, type, notes, createdAt, updatedAt);
}
