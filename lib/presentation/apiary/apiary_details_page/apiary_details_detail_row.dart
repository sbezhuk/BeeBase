part of '../apiary_details_page.dart';

final class _ApiaryDetailsDetailRow extends StatelessWidget {
  const _ApiaryDetailsDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.textSecondary),
        SizedBox(width: context.spacing.xs),
        Text(text, style: context.textStyles.body),
      ],
    );
  }
}
