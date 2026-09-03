import 'package:beebase/domain/entity/day_count.dart';
import 'package:beebase/domain/entity/hive_inspection_count.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:flutter_test/flutter_test.dart';

const _hiveWithMostInspections = HiveInspectionCount(
  hiveId: 'hive-1',
  hiveName: 'Hive #1',
  apiaryId: 'apiary-1',
  apiaryName: 'Back Garden',
  inspectionCount: 10,
);

const _activity = [DayCount(date: '2026-03-15', count: 3)];

InspectionStats _stats({int totalInspections = 42}) {
  return InspectionStats(
    totalInspections: totalInspections,
    inspectionsLast7Days: 2,
    inspectionsThisMonth: 5,
    inspectionsThisYear: 20,
    hiveWithMostInspections: _hiveWithMostInspections,
    latestInspectionAt: DateTime(2026, 3, 15),
    activityLast30Days: _activity,
  );
}

void main() {
  group('HiveInspectionCount equality', () {
    test('equal when every field matches', () {
      expect(_hiveWithMostInspections, equals(_hiveWithMostInspections));
    });

    test('not equal when inspectionCount differs', () {
      const other = HiveInspectionCount(
        hiveId: 'hive-1',
        hiveName: 'Hive #1',
        apiaryId: 'apiary-1',
        apiaryName: 'Back Garden',
        inspectionCount: 11,
      );
      expect(_hiveWithMostInspections, isNot(equals(other)));
    });
  });

  group('DayCount equality', () {
    test('equal when date and count match', () {
      const a = DayCount(date: '2026-03-15', count: 3);
      const b = DayCount(date: '2026-03-15', count: 3);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('InspectionStats equality', () {
    test(
      'equal when every field, including the 30-day activity list, matches',
      () {
        expect(_stats(), equals(_stats()));
        expect(_stats().hashCode, equals(_stats().hashCode));
      },
    );

    test('not equal when totalInspections differs', () {
      expect(
        _stats(totalInspections: 42),
        isNot(equals(_stats(totalInspections: 43))),
      );
    });
  });
}
