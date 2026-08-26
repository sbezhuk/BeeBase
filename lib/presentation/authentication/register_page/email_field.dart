part of '../register_page.dart';

final class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  String? _validate(String? value) {
    if (value == null || !value.contains('@')) {
      return 'authentication.register.validations.emailInvalid'.tr();
    }
    return serverError;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: controller.text,
      validator: _validate,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('authentication.register.emailLabel'.tr(), style: AppTextStyles.authFieldLabel),
            SizedBox(height: context.spacing.xs),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontFamily: AppFont.regular, fontSize: 15, color: AppColor.hiveBrown),
              decoration: _authFieldDecoration(hintText: 'authentication.register.emailHint'.tr(), hasError: field.hasError),
              onChanged: (value) {
                field.didChange(value);
                onChanged();
              },
            ),
            if (field.hasError) ...[SizedBox(height: context.spacing.xs), Text(field.errorText!, style: AppTextStyles.error)],
          ],
        );
      },
    );
  }
}
