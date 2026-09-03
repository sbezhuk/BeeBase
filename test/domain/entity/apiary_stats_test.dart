import 'package:beebase/domain/entity/apiary_hive_count.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:flutter_test/flutter_test.dart';

const _distribution = [
  ApiaryHiveCount(apiaryId: 'apiary-1', name: 'Back Garden', hiveCount: 6),
  ApiaryHiveCount(apiaryId: 'apiary-2', name: 'North Field', hiveCount: 4),
];

ApiaryStats _stats({int totalApiaries = 2}) {
  return ApiaryStats(
    totalApiaries: totalApiaries,
    apiariesWithoutHives: 0,
    apiaryWithMostHives: _distribution.first,
    hiveDistribution: _distribution,
  );
}

void main() {
  group('ApiaryHiveCount equality', () {
    test('equal when every field matches', () {
      const a = ApiaryHiveCount(
        apiaryId: 'apiary-1',
        name: 'Back Garden',
        hiveCount: 6,
      );
      const b = ApiaryHiveCount(
        apiaryId: 'apiary-1',
        name: 'Back Garden',
        hiveCount: 6,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when hiveCount differs', () {
      const a = ApiaryHiveCount(
        apiaryId: 'apiary-1',
        name: 'Back Garden',
        hiveCount: 6,
      );
      const b = ApiaryHiveCount(
        apiaryId: 'apiary-1',
        name: 'Back Garden',
        hiveCount: 7,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('ApiaryStats equality', () {
    test(
      'equal when every field, including the distribution list, matches',
      () {
        expect(_stats(), equals(_stats()));
        expect(_stats().hashCode, equals(_stats().hashCode));
      },
    );

    test('not equal when totalApiaries differs', () {
      expect(_stats(totalApiaries: 2), isNot(equals(_stats(totalApiaries: 3))));
    });
  });
}
