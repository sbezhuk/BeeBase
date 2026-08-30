part of '../hive_list_cubit.dart';

mixin HiveListEmitter on Cubit<HiveListState> {
  /// Bumped by [emitLoadHives]/[emitRefreshHives] — the two authoritative
  /// resets of the list — and only ever read (never bumped) by
  /// [emitLoadNextPage], so a "load more" response that lands after a
  /// concurrent refresh already reset the list is discarded instead of
  /// appending stale data onto the fresh one.
  int _generation = 0;

  Future<void> emitLoadHives(IHiveReader reader, String apiaryId) async {
    emit(const HiveListLoading());
    await _fetchFirstPage(reader, apiaryId, ++_generation);
  }

  Future<void> emitRefreshHives(IHiveReader reader, String apiaryId) =>
      _fetchFirstPage(reader, apiaryId, ++_generation);

  Future<void> _fetchFirstPage(
    IHiveReader reader,
    String apiaryId,
    int generation,
  ) async {
    final result = await reader.getHives(
      apiaryId: apiaryId,
      page: PaginationDefaults.firstPage,
      limit: PaginationDefaults.defaultLimit,
    );
    if (generation != _generation) return;
    result.fold(
      (failure) => emit(HiveListError(failure)),
      (page) => emit(
        HiveListLoaded(
          page.items,
          page: PaginationDefaults.firstPage,
          hasNext: page.hasNext,
        ),
      ),
    );
  }

  Future<void> emitLoadNextPage(IHiveReader reader, String apiaryId) async {
    final current = state;
    if (current is! HiveListLoaded ||
        current.isLoadingNextPage ||
        !current.hasNext) {
      return;
    }

    final generation = _generation;
    emit(
      current.copyWith(isLoadingNextPage: true, clearLoadNextPageFailure: true),
    );

    final result = await reader.getHives(
      apiaryId: apiaryId,
      page: current.page + 1,
      limit: PaginationDefaults.defaultLimit,
    );
    if (generation != _generation) return;

    result.fold(
      (failure) => emit(
        current.copyWith(
          isLoadingNextPage: false,
          loadNextPageFailure: failure,
        ),
      ),
      (page) => emit(
        HiveListLoaded(
          page.items,
          page: current.page + 1,
          hasNext: page.hasNext,
        ),
      ),
    );
  }
}
