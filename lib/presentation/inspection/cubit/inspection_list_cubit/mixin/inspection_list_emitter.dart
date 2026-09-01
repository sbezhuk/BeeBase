part of '../inspection_list_cubit.dart';

mixin InspectionListEmitter on Cubit<InspectionListState> {
  /// Bumped by [emitLoadInspections]/[emitRefreshInspections] — the two
  /// authoritative resets of the list — and only ever read (never bumped) by
  /// [emitLoadNextPage], so a "load more" response that lands after a
  /// concurrent refresh already reset the list is discarded instead of
  /// appending stale data onto the fresh one.
  int _generation = 0;

  Future<void> emitLoadInspections(IInspectionReader reader, String hiveId) async {
    emit(const InspectionListLoading());
    await _fetchFirstPage(reader, hiveId, ++_generation);
  }

  Future<void> emitRefreshInspections(IInspectionReader reader, String hiveId) {
    final current = state;
    if (current is InspectionListLoaded) emit(current.copyWith(isRefreshing: true));
    return _fetchFirstPage(reader, hiveId, ++_generation);
  }

  Future<void> _fetchFirstPage(IInspectionReader reader, String hiveId, int generation) async {
    final result = await reader.getInspections(
      hiveId: hiveId,
      page: PaginationDefaults.firstPage,
      limit: PaginationDefaults.defaultLimit,
    );
    if (generation != _generation) return;
    result.fold(
      (failure) => emit(InspectionListError(failure)),
      (page) => emit(
        InspectionListLoaded(page.items, page: PaginationDefaults.firstPage, hasNext: page.hasNext),
      ),
    );
  }

  Future<void> emitLoadNextPage(IInspectionReader reader, String hiveId) async {
    final current = state;
    if (current is! InspectionListLoaded || current.isLoadingNextPage || !current.hasNext) {
      return;
    }

    final generation = _generation;
    emit(current.copyWith(isLoadingNextPage: true, clearLoadNextPageFailure: true));

    final result = await reader.getInspections(
      hiveId: hiveId,
      page: current.page + 1,
      limit: PaginationDefaults.defaultLimit,
    );
    if (generation != _generation) return;

    result.fold(
      (failure) => emit(current.copyWith(isLoadingNextPage: false, loadNextPageFailure: failure)),
      (page) =>
          emit(InspectionListLoaded(page.items, page: current.page + 1, hasNext: page.hasNext)),
    );
  }
}
