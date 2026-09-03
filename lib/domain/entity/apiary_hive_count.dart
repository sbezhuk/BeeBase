final class ApiaryHiveCount {
  const ApiaryHiveCount({
    required this.apiaryId,
    required this.name,
    required this.hiveCount,
  });

  final String apiaryId;
  final String name;
  final int hiveCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiaryHiveCount &&
          other.apiaryId == apiaryId &&
          other.name == name &&
          other.hiveCount == hiveCount);

  @override
  int get hashCode => Object.hash(apiaryId, name, hiveCount);
}
