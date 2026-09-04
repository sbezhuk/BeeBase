part of '../login_page.dart';

final class _LoginFormContent extends StatelessWidget {
  const _LoginFormContent({
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),
          clipBehavior: Clip.none,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(height: context.spacing.xl * 2),
                  Text(
                    'authentication.login.title'.tr(),
                    textAlign: TextAlign.center,
                    style: context.textStyles.authTitle,
                  ),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    'authentication.login.subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: context.textStyles.authSubtitle,
                  ),
                  SizedBox(height: context.spacing.xl),
                  _EmailField(controller: emailController, serverError: emailServerError, onChanged: onEmailChanged),
                  SizedBox(height: context.spacing.md),
                  _PasswordField(
                    controller: passwordController,
                    serverError: passwordServerError,
                    onChanged: onPasswordChanged,
                  ),
                  SizedBox(height: context.spacing.sm),
                  const _ForgotPasswordAction(),
                  SizedBox(height: context.spacing.md),
                  _SubmitButton(onPressed: onSubmit),
                  const Spacer(),
                  const _CreateAccountPrompt(),
                  SizedBox(height: context.spacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
