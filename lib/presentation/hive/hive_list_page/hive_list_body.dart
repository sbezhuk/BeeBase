part of '../hive_list_page.dart';

final class _HiveListBody extends StatelessWidget {
  const _HiveListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HiveListCubit, HiveListState>(
      builder: (context, state) {
        return switch (state) {
          HiveListLoading() => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          HiveListError(:final failure) => SliverFillRemaining(hasScrollBody: false, child: _HiveListErrorView(failure: failure)),
          final HiveListLoaded loaded => _HiveListLoadedView(state: loaded),
        };
      },
    );
  }
}
