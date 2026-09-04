part of '../change_password_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChangePasswordCubit, ChangePasswordState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'profile.change_password.submit'.tr(),
          isLoading: state is ChangePasswordLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
