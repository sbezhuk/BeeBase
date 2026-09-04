import 'package:beebase/domain/entity/hive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hive1 = Hive(
    id: 'hive-1',
    apiaryId: 'apiary-1',
    name: 'Hive 1',
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final hive2 = Hive(
    id: 'hive-1',
    apiaryId: 'apiary-1',
    name: 'Hive 1',
    notes: 'notes',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final hive3 = Hive(
    id: 'hive-2',
    apiaryId: 'apiary-1',
    name: 'Hive 2',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('equality and hashCode', () {
    test('same-field instances are equal and have identical hashCodes', () {
      expect(hive1, hive2);
      expect(hive1.hashCode, hive2.hashCode);
    });

    test('instances with different fields are not equal', () {
      expect(hive1 == hive3, isFalse);
    });
  });
}
