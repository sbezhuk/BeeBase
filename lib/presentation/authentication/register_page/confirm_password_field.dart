part of '../register_page.dart';

final class _ConfirmPasswordField extends StatelessWidget {
  const _ConfirmPasswordField({required this.controller, required this.passwordController});

  final TextEditingController controller;
  final TextEditingController passwordController;

  String? _validate(String? value) {
    if (value != passwordController.text) {
      return 'authentication.register.validations.confirm_password_mismatch'.tr();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'authentication.register.confirm_password_label'.tr(),
      hintText: 'authentication.register.confirm_password_hint'.tr(),
      obscureText: true,
      validator: _validate,
    );
  }
}
