part of '../profile_edit_page.dart';

final class _ProfileEditContent extends StatelessWidget {
  const _ProfileEditContent({
    required this.firstNameController,
    required this.lastNameController,
    required this.avatarId,
    required this.avatarLocalFilePath,
    required this.resolver,
    required this.onAvatarTap,
    required this.onSubmit,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final String? avatarId;
  final String? avatarLocalFilePath;
  final AvatarImageResolver resolver;
  final VoidCallback onAvatarTap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileEditAvatarPicker(
          resolver: resolver,
          avatarId: avatarId,
          localFilePath: avatarLocalFilePath,
          onTap: onAvatarTap,
        ),
        SizedBox(height: context.spacing.xl),
        AppTextField(
          label: 'profile.edit.first_name_label'.tr(),
          controller: firstNameController,
          hintText: 'profile.edit.first_name_hint'.tr(),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'profile.edit.validations.first_name_required'.tr()
              : null,
        ),
        SizedBox(height: context.spacing.md),
        AppTextField(
          label: 'profile.edit.last_name_label'.tr(),
          controller: lastNameController,
          hintText: 'profile.edit.last_name_hint'.tr(),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'profile.edit.validations.last_name_required'.tr()
              : null,
        ),
        SizedBox(height: context.spacing.xl),
        _ProfileEditSubmitButton(onPressed: onSubmit),
      ],
    );
  }
}
