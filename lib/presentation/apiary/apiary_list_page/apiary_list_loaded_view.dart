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
            final apiary = apiaries[index];
            // Keyed by id, not just position: `_ApiaryListTile` owns a
            // `MediaGalleryCubit` (via `BlocProvider`) created once and bound
            // to whatever `apiary.id` was current at that moment. An apiary
            // created offline is later replaced in this list — same index,
            // new (real, server-assigned) id — once it syncs; without a key
            // tied to that id, Flutter treats it as the same widget updated
            // in place and reuses the old Element, so the tile's cubit stays
            // stuck on the stale local id forever and never shows a photo
            // that synced under the real one. A `ValueKey` on the id forces
            // a fresh Element (and cubit) exactly when the id changes.
            return _ApiaryListTile(key: ValueKey(apiary.id), apiary: apiary, hiveCount: state.hiveCounts[apiary.id] ?? 0);
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
