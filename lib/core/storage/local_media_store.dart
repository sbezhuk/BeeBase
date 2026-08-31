import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thin wrapper around `path_provider`'s app documents directory for photo
/// bytes — no binary data ever touches SQLite, only the resulting file path
/// string is cached (see `MediaResponse.localFilePath`). Every file this
/// store writes is keyed by [id] so the same identity (a locally-generated
/// id for a not-yet-synced photo, or the server's media id for a downloaded
/// render cache — see `MediaThumbnail`) always resolves to the same path,
/// letting a caller check for an existing copy before re-fetching it.
class LocalMediaStore {
  const LocalMediaStore();

  Future<String> save(
    Uint8List bytes, {
    required String id,
    required String extension,
  }) async {
    final path = await pathFor(id, extension: extension);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<String> pathFor(String id, {required String extension}) async {
    final directory = await _mediaDirectory();
    return p.join(directory.path, '$id.$extension');
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _mediaDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'media'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
