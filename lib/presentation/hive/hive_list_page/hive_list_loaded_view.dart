part of '../hive_list_page.dart';

final class _HiveListLoadedView extends StatelessWidget {
  const _HiveListLoadedView({required this.state});

  final HiveListLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const SliverFillRemaining(hasScrollBody: false, child: _HiveListEmptyView());
    }
    final hives = state.hives;
    final Widget trailing;
    if (state.isLoadingNextPage) {
      trailing = const Center(child: CircularProgressIndicator.adaptive());
    } else if (state.loadNextPageFailure != null) {
      trailing = const _HiveListLoadMoreError();
    } else {
      trailing = const SizedBox.shrink();
    }
    return SliverPadding(
      padding: EdgeInsets.only(top: context.spacing.md, bottom: context.spacing.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            for (final hive in hives) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
                child: _HiveListTile(hive: hive),
              ),
              SizedBox(height: context.spacing.sm),
            ],
            trailing,
          ],
        ),
      ),
    );
  }
}
