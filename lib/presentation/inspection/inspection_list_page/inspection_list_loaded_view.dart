part of '../inspection_list_page.dart';

final class _InspectionListLoadedView extends StatelessWidget {
  const _InspectionListLoadedView({required this.state});

  final InspectionListLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const SliverFillRemaining(hasScrollBody: false, child: _InspectionListEmptyView());
    }
    final inspections = state.inspections;
    final Widget trailing;
    if (state.isLoadingNextPage) {
      trailing = const Center(child: CircularProgressIndicator.adaptive());
    } else if (state.loadNextPageFailure != null) {
      trailing = const _InspectionListLoadMoreError();
    } else {
      trailing = const SizedBox.shrink();
    }
    return SliverPadding(
      padding: EdgeInsets.only(top: context.spacing.md, bottom: context.spacing.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            for (final inspection in inspections) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
                child: _InspectionListTile(inspection: inspection),
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
