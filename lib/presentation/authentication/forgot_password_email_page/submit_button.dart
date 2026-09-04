part of '../forgot_password_email_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ForgotPasswordEmailCubit, ForgotPasswordEmailState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'authentication.forgot_password.submit'.tr(),
          isLoading: state is ForgotPasswordEmailLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
