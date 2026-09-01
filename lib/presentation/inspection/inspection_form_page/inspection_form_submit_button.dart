part of '../inspection_form_page.dart';

final class _InspectionFormSubmitButton extends StatelessWidget {
  const _InspectionFormSubmitButton({required this.isEditing, required this.onPressed});

  final bool isEditing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionFormCubit, InspectionFormState>(
      builder: (context, state) {
        return PrimaryButton(
          label: isEditing
              ? 'inspection.form.submit_update'.tr()
              : 'inspection.form.submit_create'.tr(),
          isLoading: state is InspectionFormLoading,
          onPressed: onPressed,
        );
      },
    );
  }
}
