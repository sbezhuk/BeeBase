part of '../profile_page.dart';

/// The languages this app ships translations for, in the order offered —
/// each entry's [_LanguageOption.name] is its own endonym (shown the same
/// regardless of the app's current locale, matching how every other app's
/// language picker presents its options).
const _languageOptions = [
  _LanguageOption(locale: Locale('en', 'US'), name: 'English'),
  _LanguageOption(locale: Locale('uk', 'UA'), name: 'Українська'),
];

final class _LanguageOption {
  const _LanguageOption({required this.locale, required this.name});

  final Locale locale;
  final String name;
}

String _languageNameFor(Locale locale) {
  for (final option in _languageOptions) {
    if (option.locale.languageCode == locale.languageCode) {
      return option.name;
    }
  }
  return _languageOptions.first.name;
}

/// Settings-style row for switching the app's language — reuses
/// `easy_localization`'s own locale machinery (already wired into
/// [Application]'s `MaterialApp.router`), so [context.setLocale] alone is
/// enough for every `.tr()` call in the tree to rebuild in the new language
/// immediately, with no app restart.
final class _ProfileLanguageSection extends StatelessWidget {
  const _ProfileLanguageSection();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('profile.page.language'.tr().toUpperCase(), style: context.textStyles.label.copyWith(color: colors.honey.muted)),
        SizedBox(height: context.spacing.sm),
        Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm, horizontal: context.spacing.xs),
            child: Row(
              children: [
                Icon(Icons.language, size: 20, color: colors.brand.primary),
                SizedBox(width: context.spacing.sm),
                Expanded(child: Text('profile.page.language'.tr(), style: context.textStyles.body)),
                GestureDetector(
                  onTap: () => _showLanguagePicker(context),
                  child: Text(
                    _languageNameFor(context.locale),
                    style: context.textStyles.body.copyWith(color: colors.text.secondary),
                  ),
                ),
                SizedBox(width: context.spacing.xs),
                Icon(Icons.chevron_right, size: 18, color: colors.text.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LanguagePickerSheet(),
    );
  }
}

final class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final currentLocale = context.locale;
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(spacing.sm),
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        decoration: BoxDecoration(
          color: colors.surface.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.honey.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: spacing.sm),
                decoration: BoxDecoration(color: colors.honey.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'profile.page.language_sheet_title'.tr(),
                    style: context.textStyles.label.copyWith(color: colors.honey.muted),
                  ),
                ),
              ),
              for (final option in _languageOptions)
                ListTile(
                  leading: Icon(Icons.language, color: colors.brand.primary),
                  title: Text(option.name, style: context.textStyles.body),
                  trailing: option.locale.languageCode == currentLocale.languageCode
                      ? Icon(Icons.check, color: colors.brand.primary)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.setLocale(option.locale);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
