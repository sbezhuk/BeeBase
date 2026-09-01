part of '../inspection_form_page.dart';

/// A tappable field that opens a bottom sheet to choose an [InspectionType]
/// — mirrors [_InspectionFormDateField]. The sheet's options are generated
/// entirely from [InspectionType.values], so a new type needs no change
/// here, only a new enum value and its [InspectionTypeX.label].
final class _InspectionFormTypeField extends StatelessWidget {
  const _InspectionFormTypeField({required this.type, required this.onSelect});

  final InspectionType type;
  final ValueChanged<InspectionType> onSelect;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<InspectionType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InspectionTypePickerSheet(selected: type),
    );
    if (selected != null) onSelect(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('inspection.form.type_label'.tr(), style: context.textStyles.label),
        SizedBox(height: context.spacing.xs),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openPicker(context),
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
                Icon(Icons.category_outlined, size: 18, color: colors.text.secondary),
                SizedBox(width: context.spacing.sm),
                Expanded(child: Text(type.label, style: context.textStyles.body)),
                Icon(Icons.keyboard_arrow_down, size: 18, color: colors.text.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Lists every [InspectionType] as a selectable row — mirrors
/// `_MediaGalleryPickerSheet`'s sheet chrome, no new visual language.
final class _InspectionTypePickerSheet extends StatelessWidget {
  const _InspectionTypePickerSheet({required this.selected});

  final InspectionType selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
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
                decoration: BoxDecoration(
                  color: colors.honey.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (final option in InspectionType.values)
                ListTile(
                  title: Text(option.label, style: context.textStyles.body),
                  trailing: option == selected
                      ? Icon(Icons.check, color: colors.brand.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
