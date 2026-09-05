part of 'app_date_picker.dart';

/// Content of the date-picker bottom sheet: an icon, a title, the calendar
/// grid (retinted to the honey palette), then a full-width Done/Cancel
/// button pair — the same icon+title+content+actions rhythm as
/// [ConfirmationSheet], just with a calendar in place of a message.
final class _AppDatePickerSheet extends StatefulWidget {
  const _AppDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

final class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late DateTime _selectedDate = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final spacing = context.spacing;
    final baseTheme = Theme.of(context);

    return AppBottomSheetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.brand.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: colors.brand.primary,
              size: 24,
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            'core.common.select_date'.tr(),
            textAlign: TextAlign.center,
            style: textStyles.title.copyWith(fontSize: 20),
          ),
          SizedBox(height: spacing.sm),
          Theme(
            data: baseTheme.copyWith(
              colorScheme: baseTheme.colorScheme.copyWith(
                primary: colors.brand.primary,
                onPrimary: colors.brand.onPrimary,
                onSurface: colors.text.primary,
              ),
              datePickerTheme: DatePickerThemeData(
                weekdayStyle: textStyles.label.copyWith(
                  color: colors.text.secondary,
                ),
                dayStyle: textStyles.body,
                // Same muted token used for placeholder/hint text elsewhere
                // in the app — a future date reads as unavailable, not just
                // a plain day rendered in the normal text color.
                dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return colors.honey.placeholder;
                  }
                  return states.contains(WidgetState.selected)
                      ? colors.brand.onPrimary
                      : colors.text.primary;
                }),
                dayBackgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? colors.brand.primary
                      : null,
                ),
                // Today's own accent (gold) reads fine on the plain grid
                // background, but must switch to the dark onPrimary text
                // when today is also selected — otherwise it's gold text on
                // the gold selection fill, i.e. invisible.
                todayForegroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? colors.brand.onPrimary
                      : colors.brand.primary,
                ),
                todayBorder: BorderSide(color: colors.brand.primary),
                yearStyle: textStyles.body,
                yearForegroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? colors.brand.onPrimary
                      : colors.text.primary,
                ),
                yearBackgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? colors.brand.primary
                      : null,
                ),
              ),
            ),
            child: CalendarDatePicker(
              initialDate: widget.initialDate,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
            ),
          ),
          SizedBox(height: spacing.sm),
          AppSheetButton(
            label: 'core.common.done'.tr(),
            filled: true,
            color: colors.brand.primary,
            onPressed: () => Navigator.of(context).pop(_selectedDate),
          ),
          SizedBox(height: spacing.sm),
          AppSheetButton(
            label: 'core.common.cancel'.tr(),
            filled: false,
            color: colors.text.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
