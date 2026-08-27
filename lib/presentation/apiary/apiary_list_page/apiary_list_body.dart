part of '../apiary_list_page.dart';

final class _ApiaryListBody extends StatelessWidget {
  const _ApiaryListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApiaryListCubit, ApiaryListState>(
      builder: (context, state) {
        return switch (state) {
          ApiaryListLoading() => const Center(child: CircularProgressIndicator.adaptive()),
          ApiaryListError(:final failure) => _ApiaryListErrorView(failure: failure),
          ApiaryListLoaded(:final apiaries) => _ApiaryListLoadedView(apiaries: apiaries),
        };
      },
    );
  }
}
