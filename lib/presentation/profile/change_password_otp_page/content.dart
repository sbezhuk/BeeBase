part of '../change_password_otp_page.dart';

final class _ChangePasswordOtpContent extends StatelessWidget {
  const _ChangePasswordOtpContent({
    required this.otpController,
    required this.otpServerError,
    required this.onOtpChanged,
    required this.onSubmit,
  });

  final TextEditingController otpController;
  final String? otpServerError;
  final VoidCallback onOtpChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile.change_password.otp.subtitle'.tr(),
          style: context.textStyles.body,
        ),
        SizedBox(height: context.spacing.lg),
        _OtpField(
          controller: otpController,
          serverError: otpServerError,
          onChanged: onOtpChanged,
        ),
        SizedBox(height: context.spacing.lg),
        _SubmitButton(onPressed: onSubmit),
      ],
    );
  }
}
