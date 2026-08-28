part of '../apiary_form_page.dart';

final class _ApiaryFormSubmitButton extends StatelessWidget {
  const _ApiaryFormSubmitButton({required this.isEditing, required this.onPressed});

  final bool isEditing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApiaryFormCubit, ApiaryFormState>(
      builder: (context, state) {
        return PrimaryButton(
          label: isEditing ? 'apiary.form.submitUpdate'.tr() : 'apiary.form.submitCreate'.tr(),
          isLoading: state is ApiaryFormLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
