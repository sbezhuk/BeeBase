import 'package:beebase/domain/entity/apiary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final apiary1 = Apiary(
    id: 'apiary-1',
    name: 'Back Garden',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final apiary2 = Apiary(
    id: 'apiary-1',
    name: 'Back Garden',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final apiary3 = Apiary(
    id: 'apiary-2',
    name: 'North Field',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('equality and hashCode', () {
    test('identical or same-field instances are equal and have identical hashCodes', () {
      expect(apiary1, apiary2);
      expect(apiary1.hashCode, apiary2.hashCode);
    });

    test('instances with different fields are not equal', () {
      expect(apiary1 == apiary3, isFalse);
    });
  });
}
