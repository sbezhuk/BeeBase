part of '../register_page.dart';

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegisterCubit, RegisterState>(
      builder: (context, state) {
        return PrimaryButton(
          label: 'authentication.register.submit'.tr(),
          isLoading: state is RegisterLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
