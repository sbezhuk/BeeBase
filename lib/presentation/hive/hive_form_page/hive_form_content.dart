part of '../hive_form_page.dart';

final class _HiveFormContent extends StatelessWidget {
  const _HiveFormContent({
    required this.nameController,
    required this.descriptionController,
    required this.isEditing,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isEditing;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'hive.form.name_label'.tr(),
          controller: nameController,
          hintText: 'hive.form.name_hint'.tr(),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'hive.form.validations.name_required'.tr() : null,
        ),
        SizedBox(height: context.spacing.md),
        AppTextField(
          label: 'hive.form.description_label'.tr(),
          controller: descriptionController,
          hintText: 'hive.form.description_hint'.tr(),
          maxLines: 4,
        ),
        SizedBox(height: context.spacing.md),
        const MediaGallerySection(),
        SizedBox(height: context.spacing.xl),
        _HiveFormSubmitButton(isEditing: isEditing, onPressed: onSubmit),
      ],
    );
  }
}
