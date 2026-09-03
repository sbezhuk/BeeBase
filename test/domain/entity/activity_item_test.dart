import 'package:beebase/domain/entity/activity_item.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityItem _item({String notes = 'Looking healthy'}) {
  return ActivityItem(
    inspectionId: 'inspection-1',
    inspectedAt: DateTime(2026, 3, 15),
    hiveId: 'hive-1',
    hiveName: 'Hive #1',
    apiaryId: 'apiary-1',
    apiaryName: 'Back Garden',
    notes: notes,
  );
}

void main() {
  group('equality', () {
    test('equal when every field matches', () {
      expect(_item(), equals(_item()));
      expect(_item().hashCode, equals(_item().hashCode));
    });

    test('not equal when notes differ', () {
      expect(
        _item(notes: 'Looking healthy'),
        isNot(equals(_item(notes: 'Low on stores'))),
      );
    });
  });
}
