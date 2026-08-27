part of '../apiary_form_page.dart';

final class _ApiaryFormContent extends StatelessWidget {
  const _ApiaryFormContent({
    required this.nameController,
    required this.descriptionController,
    required this.locationController,
    required this.isEditing,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final bool isEditing;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ApiaryFormField(
            label: 'apiary.form.nameLabel'.tr(),
            controller: nameController,
            hintText: 'apiary.form.nameHint'.tr(),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'apiary.form.validations.nameRequired'.tr()
                : null,
          ),
          SizedBox(height: context.spacing.md),
          _ApiaryFormField(
            label: 'apiary.form.descriptionLabel'.tr(),
            controller: descriptionController,
            hintText: 'apiary.form.descriptionHint'.tr(),
            maxLines: 3,
          ),
          SizedBox(height: context.spacing.md),
          _ApiaryFormField(
            label: 'apiary.form.locationLabel'.tr(),
            controller: locationController,
            hintText: 'apiary.form.locationHint'.tr(),
          ),
          SizedBox(height: context.spacing.xl),
          _ApiaryFormSubmitButton(isEditing: isEditing, onPressed: onSubmit),
        ],
      ),
    );
  }
}
