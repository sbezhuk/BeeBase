part of '../home_page.dart';

/// Full-screen replacement for the Dashboard body while [DashboardOffline]
/// — no cached data is ever shown here (unlike Apiaries/Hives/Inspections),
/// so this is the only thing rendered until the retry succeeds.
final class _DashboardOfflineView extends StatelessWidget {
  const _DashboardOfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 40, color: colors.honey.muted),
              SizedBox(height: context.spacing.sm),
              Text(
                'dashboard.offline.title'.tr(),
                style: context.textStyles.body.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                'dashboard.offline.message'.tr(),
                style: context.textStyles.body.copyWith(color: colors.text.secondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.spacing.sm),
              RetryButton(onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
