part of '../register_page.dart';

final class _RegisterFormContent extends StatelessWidget {
  const _RegisterFormContent({
    required this.emailController,
    required this.passwordController,
    required this.emailServerError,
    required this.passwordServerError,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? emailServerError;
  final String? passwordServerError;
  final VoidCallback onEmailChanged;
  final VoidCallback onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: context.spacing.xl * 2),
                Text('authentication.register.title'.tr(), textAlign: TextAlign.center, style: AppTextStyles.authTitle),
                SizedBox(height: context.spacing.sm),
                Text('authentication.register.subtitle'.tr(), textAlign: TextAlign.center, style: AppTextStyles.authSubtitle),
                SizedBox(height: context.spacing.xl),
                _EmailField(controller: emailController, serverError: emailServerError, onChanged: onEmailChanged),
                SizedBox(height: context.spacing.md),
                _PasswordField(controller: passwordController, serverError: passwordServerError, onChanged: onPasswordChanged),
                SizedBox(height: context.spacing.lg),
                _SubmitButton(onPressed: onSubmit),
                SizedBox(height: context.spacing.xl),
                const _LoginPrompt(),
              ],
            ),
          ),
        ),
        const _TermsAndConditionsNotice(),
        SizedBox(height: context.spacing.sm),
      ],
    );
  }
}
