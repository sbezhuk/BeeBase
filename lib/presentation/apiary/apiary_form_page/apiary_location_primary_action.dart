part of '../apiary_form_page.dart';

/// The only way to set an apiary's location: a full-width tappable row
/// rather than a small icon button, since it's the sole path — there's no
/// manual text entry (see [_ApiaryLocationSection]). [label] switches
/// between "use" and "update" wording depending on whether an address has
/// already been resolved.
final class _ApiaryLocationPrimaryAction extends StatelessWidget {
  const _ApiaryLocationPrimaryAction({required this.label, required this.isLoading, required this.onPressed});

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14);
    return Material(
      color: colors.brand.primary.withValues(alpha: 0.14),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.brand.primary),
                        ),
                      )
                    : Icon(Icons.my_location, color: colors.brand.primary),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: context.textStyles.body.copyWith(fontFamily: AppFont.bold, color: colors.brand.primaryDark),
                ),
              ),
              Icon(Icons.chevron_right, color: colors.brand.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}
