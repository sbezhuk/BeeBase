part of '../change_password_page.dart';

final class _ChangePasswordContent extends StatelessWidget {
  const _ChangePasswordContent({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.otpController,
    required this.currentPasswordServerError,
    required this.newPasswordServerError,
    required this.otpServerError,
    required this.onCurrentPasswordChanged,
    required this.onNewPasswordChanged,
    required this.onOtpChanged,
    required this.onSubmit,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController otpController;
  final String? currentPasswordServerError;
  final String? newPasswordServerError;
  final String? otpServerError;
  final VoidCallback onCurrentPasswordChanged;
  final VoidCallback onNewPasswordChanged;
  final VoidCallback onOtpChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurrentPasswordField(
          controller: currentPasswordController,
          serverError: currentPasswordServerError,
          onChanged: onCurrentPasswordChanged,
        ),
        SizedBox(height: context.spacing.md),
        _NewPasswordField(
          controller: newPasswordController,
          serverError: newPasswordServerError,
          onChanged: onNewPasswordChanged,
        ),
        SizedBox(height: context.spacing.md),
        _ConfirmPasswordField(controller: confirmPasswordController, newPasswordController: newPasswordController),
        SizedBox(height: context.spacing.md),
        _OtpField(controller: otpController, serverError: otpServerError, onChanged: onOtpChanged),
        SizedBox(height: context.spacing.lg),
        _SubmitButton(onPressed: onSubmit),
      ],
    );
  }
}
