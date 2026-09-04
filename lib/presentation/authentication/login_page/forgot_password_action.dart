part of '../login_page.dart';

final class _ForgotPasswordAction extends StatelessWidget {
  const _ForgotPasswordAction();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => context.router.push(const ForgotPasswordEmailRoute()),
        child: Text('authentication.login.forgot_password_action'.tr(), style: context.textStyles.authLink),
      ),
    );
  }
}
