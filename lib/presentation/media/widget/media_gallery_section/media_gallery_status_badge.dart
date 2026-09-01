part of '../media_gallery_section.dart';

/// Small sync-status indicator overlaid on a not-yet-synced item's
/// thumbnail — reuses `ApiarySyncBadge`'s visual language (a small filled
/// circle with an icon) rather than introducing a new one.
final class _MediaGalleryStatusBadge extends StatelessWidget {
  const _MediaGalleryStatusBadge({required this.item});

  final MediaGalleryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    switch (item.status) {
      // The thumbnail itself already shows a full overlay + spinner for
      // these two in-flight states (see `MediaThumbnail`/`_isBusy`) — a
      // second small badge here would just be redundant.
      case MediaGalleryItemStatus.uploading:
      case MediaGalleryItemStatus.removing:
        return const SizedBox.shrink();
      case MediaGalleryItemStatus.pending:
      case MediaGalleryItemStatus.staged:
        return Tooltip(
          message: 'media.gallery.pending_sync'.tr(),
          child: _badge(colors, icon: Icons.sync),
        );
      case MediaGalleryItemStatus.failed:
        return Tooltip(
          message: 'media.gallery.upload_failed_retry'.tr(),
          child: GestureDetector(
            onTap: () => context.read<MediaGalleryCubit>().retry(item.localId),
            child: _badge(
              colors,
              icon: Icons.sync_problem,
              background: colors.status.error,
            ),
          ),
        );
      case MediaGalleryItemStatus.synced:
        return const SizedBox.shrink();
    }
  }

  Widget _badge(
    AppColor colors, {
    IconData? icon,
    Widget? child,
    Color? background,
  }) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: background ?? colors.brand.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child ?? Icon(icon, size: 12, color: colors.brand.onPrimary),
    );
  }
}
