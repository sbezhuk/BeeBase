import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardOverview _overview({int totalApiaries = 3}) {
  return DashboardOverview(
    totalApiaries: totalApiaries,
    totalHives: 10,
    totalInspections: 42,
    inspectionsLast7Days: 2,
    inspectionsThisMonth: 5,
    inspectionsThisYear: 20,
    apiariesWithoutHives: 1,
    hivesWithoutInspections: 2,
    avgHivesPerApiary: 3.33,
    avgInspectionsPerHive: 4.2,
    latestInspectionAt: DateTime(2026, 3, 15),
  );
}

void main() {
  group('equality', () {
    test('equal when every field matches', () {
      expect(_overview(), equals(_overview()));
      expect(_overview().hashCode, equals(_overview().hashCode));
    });

    test('not equal when a field differs', () {
      expect(
        _overview(totalApiaries: 3),
        isNot(equals(_overview(totalApiaries: 4))),
      );
    });
  });
}
