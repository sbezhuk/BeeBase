part of '../home_page.dart';

final class _DashboardEmptyView extends StatelessWidget {
  const _DashboardEmptyView({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.honey.muted),
            SizedBox(height: context.spacing.sm),
            Text(
              title,
              style: context.textStyles.body.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              subtitle,
              style: context.textStyles.body.copyWith(color: colors.text.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
