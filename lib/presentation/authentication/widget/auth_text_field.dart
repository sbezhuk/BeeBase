import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

/// Labeled text field shared by the login/register forms: a label above a
/// bordered [TextField] plus, when [obscureText] is set, a visibility
/// toggle. Validation and copy (label/hint/error strings) are the caller's
/// responsibility — this widget only renders them.
final class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.validator,
    required this.onChanged,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

final class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscureText = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: context.textStyles.authFieldLabel),
            SizedBox(height: context.spacing.xs),
            TextField(
              controller: widget.controller,
              obscureText: _obscureText,
              keyboardType: widget.keyboardType,
              style: TextStyle(fontFamily: AppFont.regular, fontSize: 15, color: context.colors.hiveBrown),
              decoration: _decoration(context, hasError: field.hasError),
              onChanged: (value) {
                field.didChange(value);
                widget.onChanged();
              },
            ),
            if (field.hasError) ...[
              SizedBox(height: context.spacing.xs),
              Padding(
                padding: EdgeInsets.only(left: context.spacing.xs / 2),
                child: Text(field.errorText!, style: context.textStyles.error),
              ),
            ],
          ],
        );
      },
    );
  }

  // The error text is rendered by the caller (flush with the field label)
  // rather than by [InputDecoration.errorText], so only the border reacts to
  // [hasError] here.
  InputDecoration _decoration(BuildContext context, {required bool hasError}) {
    final colors = context.colors;
    final normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.honeyBorder),
    );
    final errorBorder = normalBorder.copyWith(borderSide: BorderSide(color: colors.error));
    return InputDecoration(
      hintText: widget.hintText,
      hintStyle: TextStyle(fontFamily: AppFont.regular, fontSize: 15, color: colors.honeyPlaceholder),
      filled: true,
      fillColor: colors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: hasError ? errorBorder : normalBorder,
      enabledBorder: hasError ? errorBorder : normalBorder,
      focusedBorder: hasError
          ? errorBorder.copyWith(borderSide: BorderSide(color: colors.error, width: 1.5))
          : normalBorder.copyWith(borderSide: BorderSide(color: colors.primary, width: 1.5)),
      suffixIcon: widget.obscureText
          ? IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: colors.honeyPlaceholder,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            )
          : null,
    );
  }
}
