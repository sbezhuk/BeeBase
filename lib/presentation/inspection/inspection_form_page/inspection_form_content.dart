part of '../inspection_form_page.dart';

final class _InspectionFormContent extends StatelessWidget {
  const _InspectionFormContent({
    required this.selectedDate,
    required this.selectedType,
    required this.notesController,
    required this.isEditing,
    required this.onPickDate,
    required this.onSelectType,
    required this.onSubmit,
  });

  final DateTime selectedDate;
  final InspectionType selectedType;
  final TextEditingController notesController;
  final bool isEditing;
  final VoidCallback onPickDate;
  final ValueChanged<InspectionType> onSelectType;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InspectionFormDateField(date: selectedDate, onTap: onPickDate),
        SizedBox(height: context.spacing.md),
        _InspectionFormTypeField(type: selectedType, onSelect: onSelectType),
        SizedBox(height: context.spacing.md),
        AppTextField(
          label: 'inspection.form.notes_label'.tr(),
          controller: notesController,
          hintText: 'inspection.form.notes_hint'.tr(),
          maxLines: 4,
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'inspection.form.validations.notes_required'.tr()
              : null,
        ),
        SizedBox(height: context.spacing.xl),
        _InspectionFormSubmitButton(isEditing: isEditing, onPressed: onSubmit),
      ],
    );
  }
}
