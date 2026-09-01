part of '../login_page.dart';

final class _CreateAccountPrompt extends StatefulWidget {
  const _CreateAccountPrompt();

  @override
  State<_CreateAccountPrompt> createState() => _CreateAccountPromptState();
}

final class _CreateAccountPromptState extends State<_CreateAccountPrompt> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = () => context.router.push(const RegisterRoute());
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: context.textStyles.authMuted,
        children: [
          TextSpan(text: 'authentication.login.create_account_prompt'.tr()),
          TextSpan(
            text: 'authentication.login.create_account_action'.tr(),
            style: context.textStyles.authLink,
            recognizer: _recognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
