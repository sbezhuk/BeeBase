part of '../media_gallery_section.dart';

final class _MediaGalleryItemTile extends StatelessWidget {
  const _MediaGalleryItemTile({required this.item, required this.size});

  final MediaGalleryItem item;
  final double size;

  bool get _isBusy => item.status == MediaGalleryItemStatus.uploading || item.status == MediaGalleryItemStatus.removing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MediaThumbnail(item: item, size: size),
        if (item.status == MediaGalleryItemStatus.failed)
          Positioned(bottom: 2, left: 2, child: _MediaGalleryRetryBadge(item: item)),
        // Hidden while busy — the overlay spinner already covers the tile,
        // and a tap mid-request (e.g. remove during an in-flight upload,
        // before there's even a server id to delete) is a dead end today.
        if (!_isBusy) Positioned(top: 2, right: 2, child: _MediaGalleryRemoveButton(item: item)),
      ],
    );
  }
}

/// Overlaid on a photo whose last upload/remove attempt failed — tapping it
/// retries that upload against the backend.
final class _MediaGalleryRetryBadge extends StatelessWidget {
  const _MediaGalleryRetryBadge({required this.item});

  final MediaGalleryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: 'media.gallery.upload_failed_retry'.tr(),
      child: GestureDetector(
        onTap: () => context.read<MediaGalleryCubit>().retry(item.localId),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: colors.status.error, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(Icons.refresh, size: 12, color: colors.brand.onPrimary),
        ),
      ),
    );
  }
}

/// A tap always goes through [showConfirmationSheet] first, same as
/// apiary/hive delete.
final class _MediaGalleryRemoveButton extends StatelessWidget {
  const _MediaGalleryRemoveButton({required this.item});

  final MediaGalleryItem item;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'media.gallery.remove'.tr(),
      child: GestureDetector(
        onTap: () => _confirmRemove(context),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.close, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    if (item.isServerMedia && di.isRegistered<INetworkInfo>()) {
      final isOnline = await di<INetworkInfo>().isConnected;
      if (!isOnline && context.mounted) {
        _showOfflineDeleteBlockedDialog(context);
        return;
      }
    }
    if (!context.mounted) return;

    final cubit = context.read<MediaGalleryCubit>();
    showConfirmationSheet(
      context: context,
      title: 'media.gallery.delete_confirm_title'.tr(),
      message: 'media.gallery.delete_confirm_message'.tr(),
      confirmLabel: 'media.gallery.delete'.tr(),
      cancelLabel: 'media.gallery.cancel'.tr(),
      icon: Icons.delete_outline,
      onConfirm: () => cubit.remove(item.localId),
    );
  }

  void _showOfflineDeleteBlockedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('media.gallery.delete_offline_blocked_title'.tr()),
        content: Text('media.gallery.delete_offline_blocked_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('media.gallery.delete_offline_blocked_action'.tr()),
          ),
        ],
      ),
    );
  }
}

