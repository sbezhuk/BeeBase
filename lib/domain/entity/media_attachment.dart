final class MediaAttachment {
  const MediaAttachment({
    required this.id,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    this.imageUrl,
    this.localFilePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String originalFilename;
  final String contentType;
  final int sizeBytes;

  /// The authenticated URL this photo is displayed from (see
  /// `CachedMediaImage`).
  final String? imageUrl;

  /// Absolute path to the local file when this attachment is stored offline
  /// only (not yet uploaded). `CachedMediaImage` falls back to rendering from
  /// this path when [imageUrl] is null, keeping a picked photo visible in the
  /// gallery even without an internet connection.
  final String? localFilePath;

  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaAttachment &&
          other.id == id &&
          other.originalFilename == originalFilename &&
          other.contentType == contentType &&
          other.sizeBytes == sizeBytes &&
          other.imageUrl == imageUrl &&
          other.localFilePath == localFilePath &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    originalFilename,
    contentType,
    sizeBytes,
    imageUrl,
    localFilePath,
    createdAt,
    updatedAt,
  );
}
