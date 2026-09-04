part of '../forgot_password_email_page.dart';

final class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || !value.contains('@')) {
      return 'authentication.forgot_password.validations.email_invalid'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'authentication.forgot_password.email_label'.tr(),
      hintText: 'authentication.forgot_password.email_hint'.tr(),
      keyboardType: TextInputType.emailAddress,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
