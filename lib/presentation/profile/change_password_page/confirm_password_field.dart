part of '../change_password_page.dart';

final class _ConfirmPasswordField extends StatelessWidget {
  const _ConfirmPasswordField({required this.controller, required this.newPasswordController});

  final TextEditingController controller;
  final TextEditingController newPasswordController;

  String? _validate(String? value) {
    if (value != newPasswordController.text) {
      return 'profile.change_password.validations.confirm_password_mismatch'.tr();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'profile.change_password.confirm_password_label'.tr(),
      hintText: 'profile.change_password.confirm_password_hint'.tr(),
      obscureText: true,
      validator: _validate,
    );
  }
}
