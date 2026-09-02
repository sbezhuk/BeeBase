import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';

final class MediaAttachment {
  const MediaAttachment({
    required this.id,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    this.localFilePath,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = MediaSyncStatus.synced,
  });

  final String id;
  final String originalFilename;
  final String contentType;
  final int sizeBytes;

  /// Path to a local copy of this photo's bytes, if one exists — either a
  /// not-yet-uploaded (or just-uploaded, not-yet-cleaned-up) offline copy, or
  /// a downloaded render cache (see `LocalMediaStore`/`MediaThumbnail`).
  /// Never sent to the server.
  final String? localFilePath;

  final DateTime createdAt;
  final DateTime updatedAt;
  final MediaSyncStatus syncStatus;

  /// Whether this photo was attached while offline and has never reached the
  /// server yet.
  bool get isLocalOnly => LocalIdGenerator.isLocal(id);

  MediaAttachment copyWith({
    String? localFilePath,
    MediaSyncStatus? syncStatus,
  }) {
    return MediaAttachment(
      id: id,
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaAttachment &&
          other.id == id &&
          other.originalFilename == originalFilename &&
          other.contentType == contentType &&
          other.sizeBytes == sizeBytes &&
          other.localFilePath == localFilePath &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.syncStatus == syncStatus);

  @override
  int get hashCode => Object.hash(
    id,
    originalFilename,
    contentType,
    sizeBytes,
    localFilePath,
    createdAt,
    updatedAt,
    syncStatus,
  );
}
