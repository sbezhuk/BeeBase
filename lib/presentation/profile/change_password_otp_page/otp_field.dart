part of '../change_password_otp_page.dart';

final class _OtpField extends StatelessWidget {
  const _OtpField({
    required this.controller,
    required this.serverError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || !RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'profile.change_password.otp.validations.otp_invalid_format'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return OtpInputField(
      controller: controller,
      label: 'profile.change_password.otp.otp_label'.tr(),
      autofocus: true,
      validator: _validate,
      onChanged: onChanged,
    );
  }
}
