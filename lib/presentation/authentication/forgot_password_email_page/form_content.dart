part of '../forgot_password_email_page.dart';

final class _ForgotPasswordEmailFormContent extends StatelessWidget {
  const _ForgotPasswordEmailFormContent({
    required this.emailController,
    required this.emailServerError,
    required this.onEmailChanged,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final String? emailServerError;
  final VoidCallback onEmailChanged;
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
            'authentication.forgot_password.title'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authTitle,
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            'authentication.forgot_password.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authSubtitle,
          ),
          SizedBox(height: context.spacing.xl),
          _EmailField(controller: emailController, serverError: emailServerError, onChanged: onEmailChanged),
          SizedBox(height: context.spacing.lg),
          _SubmitButton(onPressed: onSubmit),
          SizedBox(height: context.spacing.xl),
        ],
      ),
    );
  }
}
