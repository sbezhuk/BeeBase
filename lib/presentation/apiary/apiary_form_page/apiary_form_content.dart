part of '../apiary_form_page.dart';

final class _ApiaryFormContent extends StatelessWidget {
  const _ApiaryFormContent({
    required this.nameController,
    required this.descriptionController,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.isEditing,
    required this.isFetchingLocation,
    required this.onSubmit,
    required this.onUseCurrentLocation,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final bool isEditing;
  final bool isFetchingLocation;
  final VoidCallback onSubmit;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ApiaryFormField(
          label: 'apiary.form.nameLabel'.tr(),
          controller: nameController,
          hintText: 'apiary.form.nameHint'.tr(),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'apiary.form.validations.nameRequired'.tr() : null,
        ),
        SizedBox(height: context.spacing.md),
        _ApiaryFormTextArea(
          label: 'apiary.form.descriptionLabel'.tr(),
          controller: descriptionController,
          hintText: 'apiary.form.descriptionHint'.tr(),
        ),
        SizedBox(height: context.spacing.md),
        _ApiaryLocationSection(
          address: locationAddress,
          latitude: latitude,
          longitude: longitude,
          isFetchingLocation: isFetchingLocation,
          onUseCurrentLocation: onUseCurrentLocation,
        ),
        SizedBox(height: context.spacing.xl),
        _ApiaryFormSubmitButton(isEditing: isEditing, onPressed: onSubmit),
      ],
    );
  }
}
