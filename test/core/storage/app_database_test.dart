import 'package:flutter_test/flutter_test.dart';

import 'sqlite_test_helper.dart';

void main() {
  test('open() creates the key_value_cache and offline_operations tables', () async {
    final database = await openTestDatabase();
    final db = await database.open();

    final tables = await db.query('sqlite_master', columns: ['name'], where: "type = 'table'");
    final tableNames = tables.map((row) => row['name']).toSet();

    expect(tableNames, containsAll(['key_value_cache', 'offline_operations']));
  });

  test('open() returns the same connection on repeated calls', () async {
    final database = await openTestDatabase();

    final first = await database.open();
    final second = await database.open();

    expect(identical(first, second), isTrue);
  });
}
