part of '../profile_edit_page.dart';

final class _ProfileEditSubmitButton extends StatelessWidget {
  const _ProfileEditSubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditCubit, ProfileEditState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'profile.edit.submit'.tr(),
          isLoading: state is ProfileEditLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
