import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/presentation/media/widget/cached_media_image.dart';
import 'package:flutter/material.dart';

part 'media_thumbnail/media_thumbnail_overlay.dart';

/// Renders one [MediaGalleryItem]'s photo, plus the busy scrim shown while
/// that photo is uploading or being removed. All the actual source-picking
/// and caching lives in [CachedMediaImage] — this only knows how to turn a
/// gallery item into the two inputs that widget needs.
final class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    required this.item,
    this.size = 72,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final MediaGalleryItem item;

  /// Used for both dimensions when [width]/[height] aren't given — the
  /// gallery strip's square tiles only ever set this.
  final double size;

  /// Override [size] independently per axis — e.g. a full-width, fixed-height
  /// hero preview (see `ApiaryPreviewImage`), which isn't square.
  final double? width;
  final double? height;

  final BorderRadius borderRadius;

  bool get _isBusy =>
      item.status == MediaGalleryItemStatus.uploading ||
      item.status == MediaGalleryItemStatus.removing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          CachedMediaImage(
            imageUrl: item.attachment?.imageUrl,
            localFilePath: item.localFilePath,
            width: width ?? size,
            height: height ?? size,
          ),
          if (_isBusy) const Positioned.fill(child: _MediaThumbnailOverlay()),
        ],
      ),
    );
  }
}
