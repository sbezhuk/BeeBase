/// The narrow slice of the shared `CachedNetworkImage` disk cache that the
/// data layer needs: seeding an entry from bytes already on disk, and
/// dropping one that no longer exists server-side.
///
/// Holds *renderable copies of already-uploaded photos*, under a
/// size/staleness policy that evicts on its own — never a durable store of
/// anything the backend doesn't already have. See [MediaImageCacheManager]
/// for the only implementation.
abstract interface class IMediaImageCache {
  /// Writes the file at [filePath] into the image cache under [imageUrl], so
  /// the first render of a just-uploaded photo is served from disk instead
  /// of re-downloading bytes this device already has. A no-op when nothing
  /// exists at [filePath].
  Future<void> seedFromFile({
    required String imageUrl,
    required String filePath,
  });

  /// Drops [imageUrl]'s cached copy — called when its photo is deleted, so a
  /// later id/URL reuse can never render the old bytes.
  Future<void> evict(String imageUrl);

  /// Returns the local cached file path for [imageUrl], downloading it if needed.
  Future<String?> getCachedFilePath(String imageUrl);

  /// Empties the entire disk cache in one call, unlike [evict] which drops a
  /// single [imageUrl] — used when every cached photo must go at once, e.g.
  /// account deletion.
  Future<void> clearAll();
}

