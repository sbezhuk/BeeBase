part of '../login_otp_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginOtpCubit, LoginOtpState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'authentication.login_otp.submit'.tr(),
          isLoading: state is LoginOtpLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
