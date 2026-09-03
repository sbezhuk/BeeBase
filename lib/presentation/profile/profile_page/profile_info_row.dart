part of '../profile_page.dart';

final class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textStyles.body.copyWith(
            color: context.colors.text.secondary,
          ),
        ),
        Text(value, style: context.textStyles.body),
      ],
    );
  }
}
