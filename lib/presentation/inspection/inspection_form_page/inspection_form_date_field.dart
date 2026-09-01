part of '../inspection_form_page.dart';

/// A tappable field that opens the platform date picker — [AppTextField]
/// isn't reused here since a date is picked, never typed.
final class _InspectionFormDateField extends StatelessWidget {
  const _InspectionFormDateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('inspection.form.dateLabel'.tr(), style: context.textStyles.label),
        SizedBox(height: context.spacing.xs),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.md,
              vertical: context.spacing.sm + context.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.honey.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: colors.text.secondary),
                SizedBox(width: context.spacing.sm),
                Text(date.toInspectionDisplayDate(), style: context.textStyles.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
