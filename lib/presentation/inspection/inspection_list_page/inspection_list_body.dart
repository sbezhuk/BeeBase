part of '../inspection_list_page.dart';

final class _InspectionListBody extends StatelessWidget {
  const _InspectionListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionListCubit, InspectionListState>(
      builder: (context, state) {
        return switch (state) {
          InspectionListLoading() => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
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
