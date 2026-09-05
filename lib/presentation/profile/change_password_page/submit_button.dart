part of '../change_password_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: 'profile.change_password.submit'.tr(),
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
