part of '../home_page.dart';

final class _DashboardOfflineView extends StatelessWidget {
  const _DashboardOfflineView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppScaffold(
      title: 'dashboard.title'.tr(),
      showBackButton: false,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 48, color: colors.status.error),
                  SizedBox(height: context.spacing.md),
                  Text(
                    'dashboard.offline.title'.tr(),
                    style: context.textStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    'dashboard.offline.subtitle'.tr(),
                    style: context.textStyles.body.copyWith(
                      color: colors.text.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.spacing.lg),
                  RetryButton(onPressed: onRetry),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
