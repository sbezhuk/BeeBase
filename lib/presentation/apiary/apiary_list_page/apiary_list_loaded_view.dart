part of '../apiary_list_page.dart';

final class _ApiaryListLoadedView extends StatelessWidget {
  const _ApiaryListLoadedView({required this.state});

  final ApiaryListLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const SliverFillRemaining(hasScrollBody: false, child: _ApiaryListEmptyView());
    }
    final apiaries = state.apiaries;
    return SliverPadding(
      padding: EdgeInsets.only(top: context.spacing.md, bottom: context.spacing.lg),
      sliver: SliverList.separated(
        itemCount: apiaries.length + 1,
        separatorBuilder: (context, index) => SizedBox(height: context.spacing.md),
        itemBuilder: (context, index) {
          if (index < apiaries.length) {
            return _ApiaryListTile(apiary: apiaries[index]);
          }
          if (state.isLoadingNextPage) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final failure = state.loadNextPageFailure;
          if (failure != null) {
            return const _ApiaryListLoadMoreError();
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
