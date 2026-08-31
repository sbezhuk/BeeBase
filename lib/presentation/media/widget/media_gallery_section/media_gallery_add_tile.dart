part of '../media_gallery_section.dart';

final class _MediaGalleryAddTile extends StatelessWidget {
  const _MediaGalleryAddTile({required this.size, required this.isLoading});

  final double size;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: 'media.gallery.addPhoto'.tr(),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : () => _showMediaPickerSheet(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.honey.creamLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.honey.border),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.add_a_photo_outlined, color: colors.brand.primary),
        ),
      ),
    );
  }
}
