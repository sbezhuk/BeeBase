part of '../inspection_details_page.dart';

/// A labeled section within the flat, divider-separated details list —
/// mirrors [_HiveDetailsInfoSection].
final class _InspectionDetailsInfoSection extends StatelessWidget {
  const _InspectionDetailsInfoSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.textStyles.label.copyWith(color: context.colors.honey.muted),
        ),
        SizedBox(height: context.spacing.sm),
        child,
      ],
    );
  }
}
