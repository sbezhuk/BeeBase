part of '../apiary_list_cubit.dart';

final class ApiaryListLoaded extends ApiaryListState {
  const ApiaryListLoaded(
    this.apiaries, {
    this.page = PaginationDefaults.firstPage,
    this.hasNext = false,
    this.isLoadingNextPage = false,
    this.loadNextPageFailure,
  });

  final List<Apiary> apiaries;

  /// The page most recently fetched into [apiaries] — the next "load more"
  /// call requests `page + 1`.
  final int page;
  final bool hasNext;

  /// True while a "load more" request is in flight — guards against a
  /// duplicate request firing (e.g. from rapid scrolling) before the
  /// current one resolves.
  final bool isLoadingNextPage;

  /// Set when the most recent "load more" attempt failed. [apiaries] is left
  /// untouched so already-loaded items never disappear because the next
  /// page failed to load.
  final Failure? loadNextPageFailure;

  bool get isEmpty => apiaries.isEmpty;

  ApiaryListLoaded copyWith({
    List<Apiary>? apiaries,
    int? page,
    bool? hasNext,
    bool? isLoadingNextPage,
    Failure? loadNextPageFailure,
    bool clearLoadNextPageFailure = false,
  }) {
    return ApiaryListLoaded(
      apiaries ?? this.apiaries,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      loadNextPageFailure: clearLoadNextPageFailure ? null : (loadNextPageFailure ?? this.loadNextPageFailure),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApiaryListLoaded) return false;
    if (other.page != page ||
        other.hasNext != hasNext ||
        other.isLoadingNextPage != isLoadingNextPage ||
        other.loadNextPageFailure != loadNextPageFailure) {
      return false;
    }
    if (other.apiaries.length != apiaries.length) return false;
    for (var i = 0; i < apiaries.length; i++) {
      if (other.apiaries[i] != apiaries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(apiaries), page, hasNext, isLoadingNextPage, loadNextPageFailure);
}
