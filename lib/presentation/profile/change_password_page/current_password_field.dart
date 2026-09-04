part of '../change_password_page.dart';

final class _CurrentPasswordField extends StatelessWidget {
  const _CurrentPasswordField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'profile.change_password.validations.current_password_required'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'profile.change_password.current_password_label'.tr(),
      hintText: 'profile.change_password.current_password_hint'.tr(),
      obscureText: true,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
