import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inspection1 = Inspection(
    id: 'inspection-1',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final inspection2 = Inspection(
    id: 'inspection-1',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final inspection3 = Inspection(
    id: 'inspection-2',
    hiveId: 'hive-1',
    date: DateTime(2026, 1, 1),
    type: InspectionType.health,
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('equality and hashCode', () {
    test('same-field instances are equal and have identical hashCodes', () {
      expect(inspection1, inspection2);
      expect(inspection1.hashCode, inspection2.hashCode);
    });

    test('instances with different fields are not equal', () {
      expect(inspection1 == inspection3, isFalse);
    });
  });
}
