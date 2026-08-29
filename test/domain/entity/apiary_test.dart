import 'package:beebase/domain/entity/apiary.dart';
import 'package:flutter_test/flutter_test.dart';

Apiary _apiary({required String id}) {
  return Apiary(id: id, name: 'Back Garden', createdAt: DateTime(2026), updatedAt: DateTime(2026));
}

void main() {
  group('isLocalOnly', () {
    test('true for a local-prefixed id (never reached the server)', () {
      expect(_apiary(id: 'local-abc123-xyz').isLocalOnly, isTrue);
    });

    test('false for a server-assigned id', () {
      expect(_apiary(id: 'apiary-1').isLocalOnly, isFalse);
    });
  });
}
