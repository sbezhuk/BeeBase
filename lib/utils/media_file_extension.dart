/// The lowercase file extension in [filename], or `'jpg'` if it has none —
/// shared by every place that derives a `LocalMediaStore` cache filename
/// from a photo's original filename (staging a pick, downloading a render
/// cache, adopting a just-synced local file under its server id).
String extensionFromFilename(String filename) {
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == filename.length - 1) return 'jpg';
  return filename.substring(dotIndex + 1).toLowerCase();
}

/// The content type to upload a picked image as, given its (lowercase) file
/// extension — shared by every place that stages a photo for upload
/// (`MediaGalleryEmitter`, `ProfileRepositoryImpl`/`ProfileOperationHandler`
/// for avatars).
String contentTypeFromExtension(String extension) => switch (extension) {
  'png' => 'image/png',
  'heic' => 'image/heic',
  'heif' => 'image/heif',
  'webp' => 'image/webp',
  'gif' => 'image/gif',
  _ => 'image/jpeg',
};
