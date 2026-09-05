part of '../change_password_page.dart';

final class _ChangePasswordContent extends StatelessWidget {
  const _ChangePasswordContent({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurrentPasswordField(controller: currentPasswordController),
        SizedBox(height: context.spacing.md),
        _NewPasswordField(controller: newPasswordController),
        SizedBox(height: context.spacing.md),
        _ConfirmPasswordField(
          controller: confirmPasswordController,
          newPasswordController: newPasswordController,
        ),
        SizedBox(height: context.spacing.lg),
        _SubmitButton(isLoading: isLoading, onPressed: onSubmit),
      ],
    );
  }
}
