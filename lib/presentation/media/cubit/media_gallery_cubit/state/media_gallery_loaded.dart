part of '../media_gallery_cubit.dart';

final class MediaGalleryLoaded extends MediaGalleryState {
  const MediaGalleryLoaded(this.items);

  final List<MediaGalleryItem> items;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MediaGalleryLoaded) return false;
    if (other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}
