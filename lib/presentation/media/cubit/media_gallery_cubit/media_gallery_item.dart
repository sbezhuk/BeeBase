import 'package:beebase/domain/entity/media_attachment.dart';

enum MediaGalleryItemStatus { staged, uploading, removing, synced, failed }

/// One photo in a `MediaGalleryCubit`'s working list — a staged pick with no
/// server counterpart yet, an in-flight upload, an in-flight removal, an
/// already-uploaded one, or one whose most recent attach/remove attempt
/// failed. Wraps [MediaAttachment] rather than being one, since a staged
/// item has no id to give it yet.
final class MediaGalleryItem {
  const MediaGalleryItem({
    required this.localId,
    this.localFilePath,
    required this.originalFilename,
    required this.contentType,
    required this.status,
    this.attachment,
    this.uploadProgress,
    this.errorMessage,
  });

  /// Stable identity for this item regardless of upload state — generated
  /// the moment the photo is picked, so the UI never rekeys the widget
  /// mid-upload even once [attachment] (with its own, different,
  /// server-assigned id) arrives.
  final String localId;

  final String? localFilePath;
  final String originalFilename;
  final String contentType;
  final MediaGalleryItemStatus status;
  final MediaAttachment? attachment;

  /// Fraction in `[0, 1]` while [status] is [MediaGalleryItemStatus.uploading].
  final double? uploadProgress;

  final String? errorMessage;

  MediaGalleryItem copyWith({
    MediaGalleryItemStatus? status,
    MediaAttachment? attachment,
    double? uploadProgress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MediaGalleryItem(
      localId: localId,
      localFilePath: localFilePath,
      originalFilename: originalFilename,
      contentType: contentType,
      status: status ?? this.status,
      attachment: attachment ?? this.attachment,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaGalleryItem &&
          other.localId == localId &&
          other.localFilePath == localFilePath &&
          other.originalFilename == originalFilename &&
          other.contentType == contentType &&
          other.status == status &&
          other.attachment == attachment &&
          other.uploadProgress == uploadProgress &&
          other.errorMessage == errorMessage);

  @override
  int get hashCode => Object.hash(
    localId,
    localFilePath,
    originalFilename,
    contentType,
    status,
    attachment,
    uploadProgress,
    errorMessage,
  );
}
