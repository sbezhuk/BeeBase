final class DashboardOverview {
  const DashboardOverview({
    required this.totalApiaries,
    required this.totalHives,
    required this.totalInspections,
    required this.inspectionsLast7Days,
    required this.inspectionsThisMonth,
    required this.inspectionsThisYear,
    required this.apiariesWithoutHives,
    required this.hivesWithoutInspections,
    required this.avgHivesPerApiary,
    required this.avgInspectionsPerHive,
    this.latestInspectionAt,
  });

  final int totalApiaries;
  final int totalHives;
  final int totalInspections;
  final int inspectionsLast7Days;
  final int inspectionsThisMonth;
  final int inspectionsThisYear;
  final int apiariesWithoutHives;
  final int hivesWithoutInspections;
  final double avgHivesPerApiary;
  final double avgInspectionsPerHive;
  final DateTime? latestInspectionAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardOverview &&
          other.totalApiaries == totalApiaries &&
          other.totalHives == totalHives &&
          other.totalInspections == totalInspections &&
          other.inspectionsLast7Days == inspectionsLast7Days &&
          other.inspectionsThisMonth == inspectionsThisMonth &&
          other.inspectionsThisYear == inspectionsThisYear &&
          other.apiariesWithoutHives == apiariesWithoutHives &&
          other.hivesWithoutInspections == hivesWithoutInspections &&
          other.avgHivesPerApiary == avgHivesPerApiary &&
          other.avgInspectionsPerHive == avgInspectionsPerHive &&
          other.latestInspectionAt == latestInspectionAt);

  @override
  int get hashCode => Object.hash(
    totalApiaries,
    totalHives,
    totalInspections,
    inspectionsLast7Days,
    inspectionsThisMonth,
    inspectionsThisYear,
    apiariesWithoutHives,
    hivesWithoutInspections,
    avgHivesPerApiary,
    avgInspectionsPerHive,
    latestInspectionAt,
  );
}
