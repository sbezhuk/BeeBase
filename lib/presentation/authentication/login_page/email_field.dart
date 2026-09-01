part of '../login_page.dart';

final class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || !value.contains('@')) {
      return 'authentication.login.validations.email_invalid'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: 'authentication.login.email_label'.tr(),
      hintText: 'authentication.login.email_hint'.tr(),
      keyboardType: TextInputType.emailAddress,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
