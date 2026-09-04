import 'dart:io';

import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/media/media_image_file_service.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The single `CachedNetworkImage` cache every remote photo in the app is
/// loaded through (see `CachedMediaImage`) — one cache, one eviction policy,
/// rather than a per-screen download-and-keep copy.
///
/// The policy is deliberately *bounded*: photos are evicted once they go
/// [_stalePeriod] unused or the cache grows past [_maxCacheObjects], so
/// storage use stops growing with the number of photos the user has ever
/// looked at. That is the whole point of BEEB-39 — a controlled cache, not a
/// permanent local mirror of every image.
final class MediaImageCacheManager extends CacheManager
    implements IMediaImageCache {
  MediaImageCacheManager({required Future<String?> Function() accessToken})
    : super(
        Config(
          cacheKey,
          stalePeriod: _stalePeriod,
          maxNrOfCacheObjects: _maxCacheObjects,
          fileService: MediaImageFileService(accessToken: accessToken),
        ),
      );

  /// Names both the cache's own folder and its metadata table.
  static const cacheKey = 'beebase_media_images';

  static const _stalePeriod = Duration(days: 14);
  static const _maxCacheObjects = 200;

  /// Caps the *decoded* images Flutter keeps in RAM. `CachedNetworkImage`
  /// hands every decode to the framework's global [ImageCache], which
  /// defaults to 100 MB — far more than a photo gallery needs, and the
  /// reason a long scroll could grow the app's memory unboundedly. Called
  /// once from `main()`.
  static void configureMemoryCache() {
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 48 << 20
      ..maximumSize = 100;
  }

  @override
  Future<void> seedFromFile({
    required String imageUrl,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }
    await putFile(
      imageUrl,
      await file.readAsBytes(),
      fileExtension: extensionFromFilename(filePath),
    );
  }

  @override
  Future<void> evict(String imageUrl) => removeFile(imageUrl);
}
