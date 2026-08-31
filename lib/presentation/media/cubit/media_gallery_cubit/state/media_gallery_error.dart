part of '../media_gallery_cubit.dart';

final class MediaGalleryError extends MediaGalleryState {
  const MediaGalleryError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaGalleryError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
