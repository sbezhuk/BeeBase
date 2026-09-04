part of '../change_password_page.dart';

final class _NewPasswordField extends StatelessWidget {
  const _NewPasswordField({required this.controller});

  final TextEditingController controller;

  String? _validate(String? value) {
    if (value == null || value.length < 8) {
      return 'profile.change_password.validations.password_too_short'.tr();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'profile.change_password.new_password_label'.tr(),
      hintText: 'profile.change_password.new_password_hint'.tr(),
      obscureText: true,
      validator: _validate,
    );
  }
}
