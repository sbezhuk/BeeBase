part of '../hive_details_page.dart';

/// A labeled section within the flat, divider-separated details list —
/// mirrors [_ApiaryDetailsInfoSection].
final class _HiveDetailsInfoSection extends StatelessWidget {
  const _HiveDetailsInfoSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.textStyles.label.copyWith(
            color: context.colors.honey.muted,
          ),
        ),
        SizedBox(height: context.spacing.sm),
        child,
      ],
    );
  }
}
