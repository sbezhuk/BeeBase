part of 'confirmation_sheet.dart';

/// A full-width sheet button: solid [color] fill when [filled], otherwise an
/// outlined variant on [color]. Mirrors [PrimaryButton]'s proportions so the
/// sheet's actions read as part of the same button language.
final class _ConfirmationSheetButton extends StatelessWidget {
  const _ConfirmationSheetButton({required this.label, required this.filled, required this.color, required this.onPressed});

  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: filled ? null : Border.all(color: colors.honeyBorder),
            ),
            child: Center(
              child: Text(label, style: context.textStyles.button.copyWith(color: filled ? colors.background : color)),
            ),
          ),
        ),
      ),
    );
  }
}
