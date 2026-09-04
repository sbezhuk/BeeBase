part of '../reset_password_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'authentication.reset_password.submit'.tr(),
          isLoading: state is ResetPasswordLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
