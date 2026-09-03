final class DayCount {
  const DayCount({required this.date, required this.count});

  /// e.g. `"2026-03-15"` — a chart axis label, not used for date arithmetic.
  final String date;

  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayCount && other.date == date && other.count == count);

  @override
  int get hashCode => Object.hash(date, count);
}
