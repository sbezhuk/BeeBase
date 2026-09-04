part of '../totp_setup_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TotpSetupCubit, TotpSetupState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'authentication.totp_setup.submit'.tr(),
          isLoading: state is TotpSetupLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
