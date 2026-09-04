part of '../forgot_password_otp_page.dart';

final class _ForgotPasswordOtpFormContent extends StatelessWidget {
  const _ForgotPasswordOtpFormContent({
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      clipBehavior: Clip.none,
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: context.spacing.xl * 2),
          Text(
            'authentication.forgot_password_otp.title'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authTitle,
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            'authentication.forgot_password_otp.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authSubtitle,
          ),
          SizedBox(height: context.spacing.xl),
          _OtpField(controller: otpController, serverError: otpServerError, onChanged: onOtpChanged),
          SizedBox(height: context.spacing.lg),
          _SubmitButton(onPressed: onSubmit),
          SizedBox(height: context.spacing.xl),
        ],
      ),
    );
  }
}
