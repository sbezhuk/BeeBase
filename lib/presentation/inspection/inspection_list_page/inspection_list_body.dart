part of '../inspection_list_page.dart';

final class _InspectionListBody extends StatelessWidget {
  const _InspectionListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionListCubit, InspectionListState>(
      builder: (context, state) {
        return switch (state) {
          // No content to render yet — the spinner itself comes from
          // `LoadingOverlay` in `InspectionListPage.build`, not this sliver.
          InspectionListLoading() => const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
          InspectionListError(:final failure) => SliverFillRemaining(
            hasScrollBody: false,
            child: _InspectionListErrorView(failure: failure),
          ),
          final InspectionListLoaded loaded => _InspectionListLoadedView(state: loaded),
        };
      },
    );
  }
}
