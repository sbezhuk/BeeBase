part of '../home_page.dart';

final class _DashboardSectionError extends StatelessWidget {
  const _DashboardSectionError({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 32,
              color: context.colors.status.error,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              failure.message.resolve(),
              style: context.textStyles.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.sm),
            _DashboardRetryButton(onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

final class _DashboardRetryButton extends StatelessWidget {
  const _DashboardRetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = 'dashboard.section_error.retry'.tr();
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => GlassButton.custom(
        onTap: onPressed,
        width: 120,
        height: 40,
        child: Text(label),
      ),
      _ => FilledButton.tonal(onPressed: onPressed, child: Text(label)),
    };
  }
}
