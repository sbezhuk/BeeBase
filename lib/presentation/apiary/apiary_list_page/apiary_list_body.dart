part of '../apiary_list_page.dart';

final class _ApiaryListBody extends StatelessWidget {
  const _ApiaryListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApiaryListCubit, ApiaryListState>(
      builder: (context, state) {
        return switch (state) {
          // No content to render yet — the spinner itself comes from
          // `LoadingOverlay` in `ApiaryListPage.build`, not this sliver.
          ApiaryListLoading() => const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
          ApiaryListError(:final failure) => SliverFillRemaining(
            hasScrollBody: false,
            child: _ApiaryListErrorView(failure: failure),
          ),
          final ApiaryListLoaded loaded => _ApiaryListLoadedView(state: loaded),
        };
      },
    );
  }
}
