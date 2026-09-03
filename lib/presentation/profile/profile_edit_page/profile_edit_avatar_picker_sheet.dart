part of '../profile_edit_page.dart';

void _showProfileAvatarPickerSheet({
  required BuildContext context,
  required VoidCallback onTakePhoto,
  required VoidCallback onPickFromGallery,
  required VoidCallback? onRemove,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileAvatarPickerSheet(
      onTakePhoto: onTakePhoto,
      onPickFromGallery: onPickFromGallery,
      onRemove: onRemove,
    ),
  );
}

/// "Take photo" / "Choose from gallery" / "Remove" bottom sheet — same
/// Material 3 sheet treatment as `MediaGalleryPickerSheet`, no new visual
/// language.
final class _ProfileAvatarPickerSheet extends StatelessWidget {
  const _ProfileAvatarPickerSheet({
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onRemove,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final VoidCallback? onRemove;

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
                  onTakePhoto();
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
                  onPickFromGallery();
                },
              ),
              if (onRemove != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: colors.status.error,
                  ),
                  title: Text(
                    'profile.edit.remove_avatar'.tr(),
                    style: context.textStyles.body.copyWith(
                      color: colors.status.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onRemove!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
