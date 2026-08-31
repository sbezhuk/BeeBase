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

  /// Writes to a uniquely-named temp file first, then renames it onto [path]
  /// — a rename within the same directory is atomic on both Android and iOS,
  /// so a reader can never observe a partially-written (corrupted) file at
  /// the final path, even if the app is killed mid-write.
  Future<String> save(
    Uint8List bytes, {
    required String id,
    required String extension,
  }) async {
    final path = await pathFor(id, extension: extension);
    final tempPath = '$path.${DateTime.now().microsecondsSinceEpoch}.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    await tempFile.rename(path);
    return path;
  }

  Future<String> pathFor(String id, {required String extension}) async {
    final directory = await _mediaDirectory();
    return p.join(directory.path, '$id.$extension');
  }

  /// The deterministic download-cache path for [id]/[extension] (see
  /// [pathFor]) if a valid copy already sits there — `null` if nothing's
  /// there, or if what's there is a zero-byte leftover from an interrupted
  /// write (deleted here so a caller's next download attempt isn't blocked
  /// by it). Lets a caller skip a redundant network re-download of a photo
  /// that's already been cached once.
  Future<String?> validExistingPath(
    String id, {
    required String extension,
  }) async {
    final path = await pathFor(id, extension: extension);
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    if (await file.length() == 0) {
      await file.delete();
      return null;
    }
    return path;
  }

  /// Moves whatever file sits at [existingPath] onto the deterministic
  /// cache path for [id]/[extension] — used to adopt a locally-staged
  /// photo's bytes under the server's real id once it finishes syncing, so
  /// it stays available offline without a redundant re-download. Returns
  /// `null` (a no-op) if nothing exists at [existingPath].
  Future<String?> adopt(
    String existingPath, {
    required String id,
    required String extension,
  }) async {
    final source = File(existingPath);
    if (!await source.exists()) {
      return null;
    }
    final targetPath = await pathFor(id, extension: extension);
    if (p.equals(existingPath, targetPath)) {
      return targetPath;
    }
    await source.rename(targetPath);
    return targetPath;
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
