part of '../totp_setup_page.dart';

final class _OtpField extends StatelessWidget {
  const _OtpField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || !RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'authentication.totp_setup.validations.otp_invalid_format'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return OtpInputField(
      controller: controller,
      label: 'authentication.totp_setup.otp_label'.tr(),
      autofocus: true,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
