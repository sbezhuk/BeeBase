import 'package:beebase/domain/entity/day_count.dart';
import 'package:beebase/domain/entity/hive_inspection_count.dart';

final class InspectionStats {
  const InspectionStats({
    required this.totalInspections,
    required this.inspectionsLast7Days,
    required this.inspectionsThisMonth,
    required this.inspectionsThisYear,
    this.hiveWithMostInspections,
    this.latestInspectionAt,
    required this.activityLast30Days,
  });

  final int totalInspections;
  final int inspectionsLast7Days;
  final int inspectionsThisMonth;
  final int inspectionsThisYear;
  final HiveInspectionCount? hiveWithMostInspections;
  final DateTime? latestInspectionAt;

  /// Always exactly 30 entries, oldest to newest ending today (UTC),
  /// zero-filled for days with no inspections.
  final List<DayCount> activityLast30Days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InspectionStats &&
          other.totalInspections == totalInspections &&
          other.inspectionsLast7Days == inspectionsLast7Days &&
          other.inspectionsThisMonth == inspectionsThisMonth &&
          other.inspectionsThisYear == inspectionsThisYear &&
          other.hiveWithMostInspections == hiveWithMostInspections &&
          other.latestInspectionAt == latestInspectionAt &&
          _listEquals(other.activityLast30Days, activityLast30Days));

  @override
  int get hashCode => Object.hash(
    totalInspections,
    inspectionsLast7Days,
    inspectionsThisMonth,
    inspectionsThisYear,
    hiveWithMostInspections,
    latestInspectionAt,
    Object.hashAll(activityLast30Days),
  );
}

bool _listEquals(List<DayCount> a, List<DayCount> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
