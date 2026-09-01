part of '../media_gallery_section.dart';

void _showMediaPickerSheet(BuildContext context) {
  final cubit = context.read<MediaGalleryCubit>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _MediaGalleryPickerSheet(cubit: cubit),
  );
}

/// "Take photo" / "Choose from gallery" bottom sheet — a Material 3 modal
/// sheet, matching the app's existing sheet patterns (see
/// `ConfirmationSheet`), no new visual language.
final class _MediaGalleryPickerSheet extends StatelessWidget {
  const _MediaGalleryPickerSheet({required this.cubit});

  final MediaGalleryCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(spacing.sm),
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        decoration: BoxDecoration(
          color: colors.surface.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.honey.border),
        ),
        // `ListTile` paints its background/ink splashes on the nearest
        // `Material` ancestor — without this, they'd render (invisibly)
        // behind the outer `Container`'s own `BoxDecoration` background,
        // which Flutter flags as a framework assertion at runtime.
        // `MaterialType.transparency` keeps the sheet's own rounded
        // background as the only visible one.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: spacing.sm),
                decoration: BoxDecoration(
                  color: colors.honey.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: colors.brand.primary,
                ),
                title: Text(
                  'media.gallery.take_photo'.tr(),
                  style: context.textStyles.body,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  cubit.takePhoto();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: colors.brand.primary,
                ),
                title: Text(
                  'media.gallery.choose_from_gallery'.tr(),
                  style: context.textStyles.body,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  cubit.pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
