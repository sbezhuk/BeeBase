part of '../hive_form_page.dart';

final class _HiveFormSubmitButton extends StatelessWidget {
  const _HiveFormSubmitButton({
    required this.isEditing,
    required this.onPressed,
  });

  final bool isEditing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HiveFormCubit, HiveFormState>(
      builder: (context, state) {
        return PrimaryButton(
          label: isEditing
              ? 'hive.form.submit_update'.tr()
              : 'hive.form.submit_create'.tr(),
          isLoading: state is HiveFormLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
