import 'dart:io';
import 'dart:typed_data';

import 'package:beebase/core/storage/local_media_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fake_path_provider_platform.dart';

void main() {
  late Directory documentsDir;
  const store = LocalMediaStore();

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp(
      'local_media_store_test',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);
  });

  tearDown(() => documentsDir.delete(recursive: true));

  group('save', () {
    test('writes retrievable bytes at the deterministic path for id', () async {
      final path = await store.save(
        Uint8List.fromList([1, 2, 3, 4]),
        id: 'media-1',
        extension: 'jpg',
      );

      expect(path, await store.pathFor('media-1', extension: 'jpg'));
      expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
    });

    test(
      'leaves no leftover temp file behind after a successful write',
      () async {
        await store.save(
          Uint8List.fromList([1, 2, 3, 4]),
          id: 'media-1',
          extension: 'jpg',
        );

        final leftovers = await Directory(
          p.dirname(await store.pathFor('media-1', extension: 'jpg')),
        ).list().where((entity) => entity.path.endsWith('.tmp')).toList();
        expect(leftovers, isEmpty);
      },
    );
  });

  group('validExistingPath', () {
    test('returns null when nothing has been cached for this id', () async {
      final result = await store.validExistingPath('media-1', extension: 'jpg');
      expect(result, isNull);
    });

    test('returns the path once a valid copy has been saved', () async {
      final saved = await store.save(
        Uint8List.fromList([1, 2, 3, 4]),
        id: 'media-1',
        extension: 'jpg',
      );

      final result = await store.validExistingPath('media-1', extension: 'jpg');

      expect(result, saved);
    });

    test('treats a zero-byte file (an interrupted write, from before the '
        'atomic-rename fix, or any other corruption) as absent, and deletes '
        'it so a fresh download is not blocked by the leftover', () async {
      final path = await store.pathFor('media-1', extension: 'jpg');
      await File(path).parent.create(recursive: true);
      await File(path).writeAsBytes(const []);

      final result = await store.validExistingPath('media-1', extension: 'jpg');

      expect(result, isNull);
      expect(await File(path).exists(), isFalse);
    });
  });

  group('adopt', () {
    test(
      'moves an existing file onto the deterministic cache path for a new id',
      () async {
        final stagingFile = File(p.join(documentsDir.path, 'staged.jpg'));
        await stagingFile.writeAsBytes([9, 9, 9]);

        final adoptedPath = await store.adopt(
          stagingFile.path,
          id: 'server-media-1',
          extension: 'jpg',
        );

        expect(
          adoptedPath,
          await store.pathFor('server-media-1', extension: 'jpg'),
        );
        expect(await stagingFile.exists(), isFalse);
        expect(await File(adoptedPath!).readAsBytes(), [9, 9, 9]);
      },
    );

    test(
      'is a no-op returning null when the source file does not exist',
      () async {
        final result = await store.adopt(
          p.join(documentsDir.path, 'missing.jpg'),
          id: 'server-media-1',
          extension: 'jpg',
        );

        expect(result, isNull);
      },
    );
  });

  group('delete', () {
    test('removes a file that exists', () async {
      final path = await store.save(
        Uint8List.fromList([1, 2, 3]),
        id: 'media-1',
        extension: 'jpg',
      );

      await store.delete(path);

      expect(await File(path).exists(), isFalse);
    });

    test('is a no-op for a path that does not exist', () async {
      await store.delete(p.join(documentsDir.path, 'missing.jpg'));
    });
  });
}
