part of '../register_page.dart';

final class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || value.length < 8) {
      return 'authentication.register.validations.passwordTooShort'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'authentication.register.passwordLabel'.tr(),
      hintText: 'authentication.register.passwordHint'.tr(),
      obscureText: true,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
