part of '../profile_edit_page.dart';

/// A tappable [ProfileAvatar] with a small edit badge, opening the
/// take-photo/choose-from-gallery/remove sheet — the edit-form counterpart
/// to the read-only avatar shown on [ProfilePage].
final class _ProfileEditAvatarPicker extends StatelessWidget {
  const _ProfileEditAvatarPicker({
    required this.resolver,
    required this.avatarId,
    required this.localFilePath,
    required this.onTap,
  });

  final AvatarPathResolver resolver;
  final String? avatarId;
  final String? localFilePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            ProfileAvatar(
              resolver: resolver,
              avatarId: avatarId,
              localFilePath: localFilePath,
              size: 112,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.brand.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.surface.background,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: colors.brand.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
