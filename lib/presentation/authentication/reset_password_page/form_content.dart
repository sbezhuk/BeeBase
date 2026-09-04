part of '../reset_password_page.dart';

final class _ResetPasswordFormContent extends StatelessWidget {
  const _ResetPasswordFormContent({
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.newPasswordServerError,
    required this.confirmPasswordServerError,
    required this.onNewPasswordChanged,
    required this.onConfirmPasswordChanged,
    required this.onSubmit,
  });

  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final String? newPasswordServerError;
  final String? confirmPasswordServerError;
  final VoidCallback onNewPasswordChanged;
  final VoidCallback onConfirmPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      clipBehavior: Clip.none,
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: context.spacing.xl * 2),
          Text(
            'authentication.reset_password.title'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authTitle,
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            'authentication.reset_password.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authSubtitle,
          ),
          SizedBox(height: context.spacing.xl),
          _NewPasswordField(
            controller: newPasswordController,
            serverError: newPasswordServerError,
            onChanged: onNewPasswordChanged,
          ),
          SizedBox(height: context.spacing.md),
          _ConfirmPasswordField(
            controller: confirmPasswordController,
            newPasswordController: newPasswordController,
            serverError: confirmPasswordServerError,
            onChanged: onConfirmPasswordChanged,
          ),
          SizedBox(height: context.spacing.lg),
          _SubmitButton(onPressed: onSubmit),
          SizedBox(height: context.spacing.xl),
        ],
      ),
    );
  }
}
