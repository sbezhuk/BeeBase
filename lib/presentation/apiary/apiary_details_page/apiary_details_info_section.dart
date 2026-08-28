part of '../apiary_details_page.dart';

/// A labeled section within the flat, divider-separated details list —
/// same small-caps label treatment as [ApiarySectionCard], minus the boxed
/// card chrome, since this page reads as one continuous list of rows rather
/// than stacked cards.
final class _ApiaryDetailsInfoSection extends StatelessWidget {
  const _ApiaryDetailsInfoSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: context.textStyles.label.copyWith(color: context.colors.honeyMuted)),
        SizedBox(height: context.spacing.sm),
        child,
      ],
    );
  }
}
