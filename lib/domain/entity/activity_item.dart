final class ActivityItem {
  const ActivityItem({
    required this.inspectionId,
    required this.inspectedAt,
    required this.hiveId,
    required this.hiveName,
    required this.apiaryId,
    required this.apiaryName,
    required this.notes,
  });

  final String inspectionId;
  final DateTime inspectedAt;
  final String hiveId;
  final String hiveName;
  final String apiaryId;
  final String apiaryName;
  final String notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityItem &&
          other.inspectionId == inspectionId &&
          other.inspectedAt == inspectedAt &&
          other.hiveId == hiveId &&
          other.hiveName == hiveName &&
          other.apiaryId == apiaryId &&
          other.apiaryName == apiaryName &&
          other.notes == notes);

  @override
  int get hashCode => Object.hash(
    inspectionId,
    inspectedAt,
    hiveId,
    hiveName,
    apiaryId,
    apiaryName,
    notes,
  );
}
