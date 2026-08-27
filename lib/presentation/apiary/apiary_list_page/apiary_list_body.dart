part of '../apiary_list_page.dart';

final class _ApiaryListBody extends StatelessWidget {
  const _ApiaryListBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApiaryListCubit, ApiaryListState>(
      builder: (context, state) {
        return switch (state) {
          ApiaryListLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          ApiaryListError(:final failure) => _ApiaryListErrorView(
            failure: failure,
          ),
          ApiaryListLoaded(:final apiaries) => _ApiaryListLoadedView(
            apiaries: apiaries,
          ),
        };
      },
    );
  }
}

final class _ApiaryListLoadedView extends StatelessWidget {
  const _ApiaryListLoadedView({required this.apiaries});

  final List<Apiary> apiaries;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ApiaryListCubit>();
    if (apiaries.isEmpty) {
      return RefreshIndicator(
        onRefresh: cubit.refresh,
        child: const _ApiaryListEmptyView(),
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView.separated(
        padding: EdgeInsets.all(context.spacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: apiaries.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: context.spacing.sm),
        itemBuilder: (context, index) =>
            _ApiaryListTile(apiary: apiaries[index]),
      ),
    );
  }
}
