part of '../apiary_list_cubit.dart';

mixin ApiaryListEmitter on Cubit<ApiaryListState> {
  /// Bumped by [emitLoadApiaries]/[emitRefreshApiaries] — the two
  /// authoritative resets of the list — and only ever read (never bumped)
  /// by [emitLoadNextPage], so a "load more" response that lands after a
  /// concurrent refresh already reset the list is discarded instead of
  /// appending stale data onto the fresh one.
  int _generation = 0;

  Future<void> emitLoadApiaries(IApiaryReader reader) async {
    emit(const ApiaryListLoading());
    await _fetchFirstPage(reader, ++_generation);
  }

  Future<void> emitRefreshApiaries(IApiaryReader reader) => _fetchFirstPage(reader, ++_generation);

  Future<void> _fetchFirstPage(IApiaryReader reader, int generation) async {
    final result = await reader.getApiaries(page: PaginationDefaults.firstPage, limit: PaginationDefaults.defaultLimit);
    if (generation != _generation) return;
    result.fold(
      (failure) => emit(ApiaryListError(failure)),
      (page) => emit(ApiaryListLoaded(page.items, page: PaginationDefaults.firstPage, hasNext: page.hasNext)),
    );
  }

  Future<void> emitLoadNextPage(IApiaryReader reader) async {
    final current = state;
    if (current is! ApiaryListLoaded || current.isLoadingNextPage || !current.hasNext) {
      return;
    }

    final generation = _generation;
    emit(current.copyWith(isLoadingNextPage: true, clearLoadNextPageFailure: true));

    final result = await reader.getApiaries(page: current.page + 1, limit: PaginationDefaults.defaultLimit);
    if (generation != _generation) return;

    result.fold(
      (failure) => emit(current.copyWith(isLoadingNextPage: false, loadNextPageFailure: failure)),
      (page) => emit(ApiaryListLoaded(page.items, page: current.page + 1, hasNext: page.hasNext)),
    );
  }
}
