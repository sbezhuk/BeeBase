import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';

/// The single shared text input across the app — label above a bordered,
/// filled field, with a colored/widened border for the focus state. Every
/// screen that needs a text input should reach for this instead of styling
/// a [TextField]/[TextFormField] directly.
///
/// Variations (multi-line, obscured, icons, keyboard config, ...) are all
/// configuration on this one widget — don't fork a feature-specific field
/// class for them.
final class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    super.key,
  }) : assert(
         !obscureText || maxLines == 1,
         'obscureText fields must be single-line',
       );

  final TextEditingController controller;
  final String label;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final Widget? prefixIcon;

  /// Ignored when [obscureText] is set — the field renders its own
  /// visibility toggle as the suffix in that case.
  final Widget? suffixIcon;

  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

final class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late bool _obscureText = widget.obscureText;

  @override
  void dispose() {
    // Only dispose the node we created — a caller-supplied one is theirs to
    // manage (e.g. to move focus to the next field on submit).
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = BorderRadius.circular(14);

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (field) {
        final normalBorder = OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.honey.border),
        );
        final errorBorder = normalBorder.copyWith(
          borderSide: BorderSide(color: colors.status.error),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: context.textStyles.label),
            SizedBox(height: spacing.xs),
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              obscureText: _obscureText,
              maxLines: _obscureText ? 1 : widget.maxLines,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              style: context.textStyles.body,
              cursorColor: colors.brand.primary,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: context.textStyles.body.copyWith(
                  color: colors.honey.placeholder,
                ),
                filled: true,
                fillColor: colors.surface.card,
                contentPadding: widget.maxLines > 1
                    ? EdgeInsets.all(spacing.md)
                    : EdgeInsets.symmetric(
                        horizontal: spacing.md,
                        vertical: spacing.sm + spacing.xs,
                      ),
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.obscureText
                    ? _visibilityToggle(colors)
                    : widget.suffixIcon,
                border: field.hasError ? errorBorder : normalBorder,
                enabledBorder: field.hasError ? errorBorder : normalBorder,
                focusedBorder: field.hasError
                    ? errorBorder.copyWith(
                        borderSide: BorderSide(
                          color: colors.status.error,
                          width: 1.5,
                        ),
                      )
                    : normalBorder.copyWith(
                        borderSide: BorderSide(
                          color: colors.brand.primary,
                          width: 1.5,
                        ),
                      ),
              ),
              onChanged: (value) {
                field.didChange(value);
                widget.onChanged?.call();
              },
            ),
            if (field.hasError) ...[
              SizedBox(height: spacing.xs),
              Padding(
                padding: EdgeInsets.only(left: spacing.xs / 2),
                child: Text(field.errorText!, style: context.textStyles.error),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _visibilityToggle(AppColor colors) {
    return IconButton(
      icon: Icon(
        _obscureText
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: colors.honey.placeholder,
        size: 20,
      ),
      onPressed: () => setState(() => _obscureText = !_obscureText),
    );
  }
}
