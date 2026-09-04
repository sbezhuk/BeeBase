part of '../reset_password_page.dart';

final class _ConfirmPasswordField extends StatelessWidget {
  const _ConfirmPasswordField({
    required this.controller,
    required this.newPasswordController,
    required this.serverError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final TextEditingController newPasswordController;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value != newPasswordController.text) {
      return 'authentication.reset_password.validations.confirm_password_mismatch'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'authentication.reset_password.confirm_password_label'.tr(),
      hintText: 'authentication.reset_password.confirm_password_hint'.tr(),
      obscureText: true,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
