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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textStyles.label),
        SizedBox(height: context.spacing.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hintText),
          validator: validator,
        ),
      ],
    );
  }
}
