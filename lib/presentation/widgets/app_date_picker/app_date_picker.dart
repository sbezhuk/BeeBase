import 'package:beebase/presentation/widgets/app_bottom_sheet/app_bottom_sheet.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

part 'app_date_picker_sheet.dart';

/// Drop-in, themed replacement for [showDatePicker] — presented as a bottom
/// sheet built on [AppBottomSheetCard]/[AppSheetButton], the exact same
/// chrome [ConfirmationSheet] uses, so every modal in the app reads as one
/// component family. Same call shape as [showDatePicker] (resolves to the
/// picked [DateTime], or null if cancelled) so existing callers don't change.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showAppBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AppDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}
