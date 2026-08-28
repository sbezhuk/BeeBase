part of '../login_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'authentication.login.submit'.tr(),
          isLoading: state is LoginLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
