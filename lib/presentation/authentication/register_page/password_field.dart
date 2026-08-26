part of '../register_page.dart';

final class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.serverError, required this.onChanged});

  final TextEditingController controller;
  final String? serverError;
  final VoidCallback onChanged;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

final class _PasswordFieldState extends State<_PasswordField> {
  bool _obscureText = true;

  String? _validate(String? value) {
    if (value == null || value.length < 8) {
      return 'authentication.register.validations.passwordTooShort'.tr();
    }
    return widget.serverError;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: _validate,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('authentication.register.passwordLabel'.tr(), style: AppTextStyles.authFieldLabel),
            SizedBox(height: context.spacing.xs),
            TextField(
              controller: widget.controller,
              obscureText: _obscureText,
              style: const TextStyle(fontFamily: AppFont.regular, fontSize: 15, color: AppColor.hiveBrown),
              decoration: _authFieldDecoration(hintText: 'authentication.register.passwordHint'.tr(), hasError: field.hasError)
                  .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColor.honeyPlaceholder,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                  ),
              onChanged: (value) {
                field.didChange(value);
                widget.onChanged();
              },
            ),
            if (field.hasError) ...[SizedBox(height: context.spacing.xs), Text(field.errorText!, style: AppTextStyles.error)],
          ],
        );
      },
    );
  }
}
