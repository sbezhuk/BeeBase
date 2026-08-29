import 'package:beebase/data/data_source/sqlite_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/storage/sqlite_test_helper.dart';

void main() {
  test('read() returns null when nothing was ever stored', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<String>(
      database: database,
      key: 'greeting',
      toJson: (value) => value,
      fromJson: (json) => json as String,
    );

    expect(await source.read(), isNull);
  });

  test('write() then read() round-trips the value', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<List<int>>(
      database: database,
      key: 'numbers',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<int>(),
    );

    await source.write([1, 2, 3]);

    expect(await source.read(), [1, 2, 3]);
  });

  test('write() overwrites a previous value under the same key', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<String>(
      database: database,
      key: 'name',
      toJson: (value) => value,
      fromJson: (json) => json as String,
    );

    await source.write('first');
    await source.write('second');

    expect(await source.read(), 'second');
  });

  test('clear() removes the stored value', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<String>(
      database: database,
      key: 'name',
      toJson: (value) => value,
      fromJson: (json) => json as String,
    );
    await source.write('value');

    await source.clear();

    expect(await source.read(), isNull);
  });

  test('modify() applies the update against the current value and persists it', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<List<int>>(
      database: database,
      key: 'numbers',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<int>(),
    );
    await source.write([1]);

    await source.modify((current) => [...?current, 2]);

    expect(await source.read(), [1, 2]);
  });

  test('modify() with nothing stored yet receives null as current', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<List<int>>(
      database: database,
      key: 'numbers',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<int>(),
    );

    await source.modify((current) => [...?current, 1]);

    expect(await source.read(), [1]);
  });

  test('two concurrent modify() calls on the same key do not lose an update', () async {
    final database = await openTestDatabase();
    final source = SqliteLocalDataSource<List<int>>(
      database: database,
      key: 'numbers',
      toJson: (value) => value,
      fromJson: (json) => (json as List<dynamic>).cast<int>(),
    );

    final first = source.modify((current) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return [...?current, 1];
    });
    final second = source.modify((current) => [...?current, 2]);
    await Future.wait([first, second]);

    expect((await source.read())!.toSet(), {1, 2});
  });
}
