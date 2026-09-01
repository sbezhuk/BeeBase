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
        if (item.status != MediaGalleryItemStatus.synced)
          Positioned(bottom: 2, left: 2, child: _MediaGalleryStatusBadge(item: item)),
        // Hidden while busy — the overlay spinner already covers the tile,
        // and a tap mid-request (e.g. remove during an in-flight upload,
        // before there's even a server id to delete) is a dead end today.
        if (!_isBusy) Positioned(top: 2, right: 2, child: _MediaGalleryRemoveButton(item: item)),
      ],
    );
  }
}

/// A never-synced ([MediaGalleryItem.isLocalOnly]) photo is always
/// deletable, online or off. An already-synced photo requires live
/// connectivity — [MediaRepositoryImpl] enforces this too, but hiding the
/// button here (via [ConnectivityCubit]) avoids a tap that silently fails,
/// mirroring `_ApiaryDeleteLink`/`_HiveDeleteLink`. A tap always goes through
/// [showConfirmationSheet] first, same as apiary/hive delete.
final class _MediaGalleryRemoveButton extends StatelessWidget {
  const _MediaGalleryRemoveButton({required this.item});

  final MediaGalleryItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isLocalOnly) {
      return _buildButton(context);
    }
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        if (state is ConnectivityOffline) {
          return const SizedBox.shrink();
        }
        return _buildButton(context);
      },
    );
  }

  Widget _buildButton(BuildContext context) {
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

  void _confirmRemove(BuildContext context) {
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
}
