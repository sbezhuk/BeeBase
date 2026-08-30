part of '../hive_list_page.dart';

/// Inline row shown at the bottom of the list when a "load more" request
/// fails — deliberately not a resized [_RetryButton] (that's a fixed-size
/// full-screen CTA); this is a single tappable row so the already-loaded
/// items above it stay the focus of the screen.
final class _HiveListLoadMoreError extends StatelessWidget {
  const _HiveListLoadMoreError();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => context.read<HiveListCubit>().retryLoadNextPage(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.spacing.md,
          horizontal: context.spacing.lg,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 18, color: colors.status.error),
            SizedBox(width: context.spacing.sm),
            Flexible(
              child: Text(
                'hive.list.loadMoreError'.tr(),
                style: context.textStyles.body.copyWith(
                  color: colors.status.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: context.spacing.sm),
            Text(
              'hive.list.retry'.tr(),
              style: context.textStyles.body.copyWith(
                color: colors.brand.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
