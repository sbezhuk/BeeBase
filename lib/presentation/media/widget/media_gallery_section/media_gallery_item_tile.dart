part of '../media_gallery_section.dart';

final class _MediaGalleryItemTile extends StatelessWidget {
  const _MediaGalleryItemTile({required this.item, required this.size});

  final MediaGalleryItem item;
  final double size;

  bool get _isBusy =>
      item.status == MediaGalleryItemStatus.uploading ||
      item.status == MediaGalleryItemStatus.removing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MediaThumbnail(item: item, size: size),
        if (item.status != MediaGalleryItemStatus.synced)
          Positioned(
            bottom: 2,
            left: 2,
            child: _MediaGalleryStatusBadge(item: item),
          ),
        // Hidden while busy — the overlay spinner already covers the tile,
        // and a tap mid-request (e.g. remove during an in-flight upload,
        // before there's even a server id to delete) is a dead end today.
        if (!_isBusy)
          Positioned(
            top: 2,
            right: 2,
            child: _MediaGalleryRemoveButton(localId: item.localId),
          ),
      ],
    );
  }
}

final class _MediaGalleryRemoveButton extends StatelessWidget {
  const _MediaGalleryRemoveButton({required this.localId});

  final String localId;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'media.gallery.remove'.tr(),
      child: GestureDetector(
        onTap: () => context.read<MediaGalleryCubit>().remove(localId),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.close, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
