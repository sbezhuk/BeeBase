part of '../apiary_form_page.dart';

final class _ApiaryFormField extends StatelessWidget {
  const _ApiaryFormField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(12);
    OutlineInputBorder borderWith(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textStyles.label),
        SizedBox(height: context.spacing.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: context.textStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: colors.background,
            contentPadding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.sm),
            border: borderWith(colors.honeyBorder),
            enabledBorder: borderWith(colors.honeyBorder),
            focusedBorder: borderWith(colors.primary, width: 1.5),
            errorBorder: borderWith(colors.error),
            focusedErrorBorder: borderWith(colors.error, width: 1.5),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
