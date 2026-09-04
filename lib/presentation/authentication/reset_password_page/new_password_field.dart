part of '../reset_password_page.dart';

final class _NewPasswordField extends StatelessWidget {
  const _NewPasswordField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || value.length < 8) {
      return 'authentication.reset_password.validations.password_too_short'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'authentication.reset_password.new_password_label'.tr(),
      hintText: 'authentication.reset_password.new_password_hint'.tr(),
      obscureText: true,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
