part of '../register_page.dart';

final class _LoginPrompt extends StatefulWidget {
  const _LoginPrompt();

  @override
  State<_LoginPrompt> createState() => _LoginPromptState();
}

final class _LoginPromptState extends State<_LoginPrompt> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = () => context.router.pop();
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
          TextSpan(text: 'authentication.register.haveAccountPrompt'.tr()),
          TextSpan(
            text: 'authentication.register.haveAccountAction'.tr(),
            style: context.textStyles.authLink,
            recognizer: _recognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
