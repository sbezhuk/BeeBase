part of '../hive_details_page.dart';

final class _HiveDetailsDetailRow extends StatelessWidget {
  const _HiveDetailsDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.text.secondary),
        SizedBox(width: context.spacing.xs),
        Text(text, style: context.textStyles.body),
      ],
    );
  }
}
