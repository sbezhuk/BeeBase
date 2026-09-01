part of '../hive_list_page.dart';

final class _HiveListBody extends StatelessWidget {
  const _HiveListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HiveListCubit, HiveListState>(
      builder: (context, state) {
        return switch (state) {
          // No content to render yet — the spinner itself comes from
          // `LoadingOverlay` in `HiveListPage.build`, not this sliver.
          HiveListLoading() => const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
          HiveListError(:final failure) => SliverFillRemaining(hasScrollBody: false, child: _HiveListErrorView(failure: failure)),
          final HiveListLoaded loaded => _HiveListLoadedView(state: loaded),
        };
      },
    );
  }
}
