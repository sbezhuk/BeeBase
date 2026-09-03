final class HiveInspectionCount {
  const HiveInspectionCount({
    required this.hiveId,
    required this.hiveName,
    required this.apiaryId,
    required this.apiaryName,
    required this.inspectionCount,
  });

  final String hiveId;
  final String hiveName;
  final String apiaryId;
  final String apiaryName;
  final int inspectionCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiveInspectionCount &&
          other.hiveId == hiveId &&
          other.hiveName == hiveName &&
          other.apiaryId == apiaryId &&
          other.apiaryName == apiaryName &&
          other.inspectionCount == inspectionCount);

  @override
  int get hashCode =>
      Object.hash(hiveId, hiveName, apiaryId, apiaryName, inspectionCount);
}
