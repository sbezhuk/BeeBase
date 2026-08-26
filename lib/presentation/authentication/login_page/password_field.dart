part of '../login_page.dart';

final class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(labelText: 'authentication.login.passwordLabel'.tr()),
      onChanged: (_) => onChanged(),
      validator: (value) {
        if (value == null || value.length < 8) {
          return 'authentication.login.validations.passwordTooShort'.tr();
        }
        return serverError;
      },
    );
  }
}
