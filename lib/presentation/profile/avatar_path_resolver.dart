import 'dart:io';
import 'dart:typed_data';

import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/repositories/media_reader.dart';

/// Resolves the local file path a `ProfileAvatar` should render an avatar
/// from — mirrors `MediaGalleryEmitter.resolveItemDisplayPath`'s
/// local-file-or-download logic, but for a single avatar id rather than a
/// gallery of `MediaGalleryItem`s (which is why this isn't just reuse of
/// that cubit — see `ProfileRepositoryImpl`'s doc on why avatars don't go
/// through `MediaOwnerType`/`IOwnerImageWriter` at all).
final class AvatarPathResolver {
  const AvatarPathResolver({
    required this.mediaReader,
    required this.localMediaStore,
  });

  final IMediaReader mediaReader;
  final LocalMediaStore localMediaStore;

  /// `null` [avatarId] means no avatar is set. A local (not-yet-synced)
  /// [avatarId] (see [LocalIdGenerator.isLocal]) always resolves from
  /// [localFilePath] — there's nothing to download yet.
  Future<String?> resolve({
    required String? avatarId,
    required String? localFilePath,
  }) async {
    if (localFilePath != null && await File(localFilePath).exists()) {
      return localFilePath;
    }
    if (avatarId == null || LocalIdGenerator.isLocal(avatarId)) {
      return null;
    }

    final cachedPath = await localMediaStore.validExistingPath(
      avatarId,
      extension: 'jpg',
    );
    if (cachedPath != null) {
      return cachedPath;
    }

    final result = await mediaReader.downloadMedia(avatarId);
    return result.fold((_) => null, (bytes) async {
      final path = await localMediaStore.save(
        Uint8List.fromList(bytes),
        id: avatarId,
        extension: 'jpg',
      );
      await mediaReader.cacheDownloadedMedia(avatarId, path);
      return path;
    });
  }
}
