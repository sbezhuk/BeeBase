part of '../apiary_form_page.dart';

/// A single-line form field: a plain caption above the input — the same
/// label-above-field convention as `AuthTextField` and [ApiarySectionCard] —
/// with a focus glow that echoes [PrimaryButton]'s gradient shadow language.
/// Reserved for one-line inputs — multi-line fields use [_ApiaryFormTextArea]
/// instead.
final class _ApiaryFormField extends StatefulWidget {
  const _ApiaryFormField({required this.label, required this.controller, required this.hintText, this.validator});

  final String label;
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;

  @override
  State<_ApiaryFormField> createState() => _ApiaryFormFieldState();
}

final class _ApiaryFormFieldState extends State<_ApiaryFormField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14);
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (field) {
        final normalBorder = OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.honey.border),
        );
        final errorBorder = normalBorder.copyWith(borderSide: BorderSide(color: colors.status.error));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: context.textStyles.label),
            SizedBox(height: context.spacing.xs),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: colors.brand.primary.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : const [],
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                style: context.textStyles.body,
                cursorColor: colors.brand.primary,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  filled: true,
                  fillColor: colors.surface.card,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.spacing.md,
                    vertical: context.spacing.sm + context.spacing.xs,
                  ),
                  border: field.hasError ? errorBorder : normalBorder,
                  enabledBorder: field.hasError ? errorBorder : normalBorder,
                  focusedBorder: field.hasError
                      ? errorBorder.copyWith(borderSide: BorderSide(color: colors.status.error, width: 1.5))
                      : normalBorder.copyWith(borderSide: BorderSide(color: colors.brand.primary, width: 1.5)),
                ),
                onChanged: field.didChange,
              ),
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
}
