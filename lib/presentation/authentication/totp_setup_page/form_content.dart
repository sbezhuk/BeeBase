part of '../totp_setup_page.dart';

final class _TotpSetupFormContent extends StatelessWidget {
  const _TotpSetupFormContent({
    required this.challenge,
    required this.otpController,
    required this.otpServerError,
    required this.onOtpChanged,
    required this.onSubmit,
  });

  final TotpSetupChallenge challenge;
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
          Text('authentication.totp_setup.title'.tr(), textAlign: TextAlign.center, style: context.textStyles.authTitle),
          SizedBox(height: context.spacing.sm),
          Text(
            'authentication.totp_setup.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: context.textStyles.authSubtitle,
          ),
          SizedBox(height: context.spacing.xl),
          _QrCodeCard(challenge: challenge),
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
