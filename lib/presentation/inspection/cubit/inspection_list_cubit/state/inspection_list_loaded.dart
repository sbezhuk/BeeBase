part of '../inspection_list_cubit.dart';

final class InspectionListLoaded extends InspectionListState {
  const InspectionListLoaded(
    this.inspections, {
    this.page = PaginationDefaults.firstPage,
    this.hasNext = false,
    this.isLoadingNextPage = false,
    this.loadNextPageFailure,
    this.isRefreshing = false,
  });

  final List<Inspection> inspections;

  /// The page most recently fetched into [inspections] — the next "load
  /// more" call requests `page + 1`.
  final int page;
  final bool hasNext;

  /// True while a "load more" request is in flight — guards against a
  /// duplicate request firing (e.g. from rapid scrolling) before the
  /// current one resolves.
  final bool isLoadingNextPage;

  /// Set when the most recent "load more" attempt failed. [inspections] is
  /// left untouched so already-loaded items never disappear because the
  /// next page failed to load.
  final Failure? loadNextPageFailure;

  /// True while a pull-to-refresh (or a refresh triggered by a sibling
  /// list's `RefreshNotifier`) is in flight — drives `LoadingOverlay` so the
  /// refetch is visible even when nothing pulled the list down by hand.
  final bool isRefreshing;

  bool get isEmpty => inspections.isEmpty;

  InspectionListLoaded copyWith({
    List<Inspection>? inspections,
    int? page,
    bool? hasNext,
    bool? isLoadingNextPage,
    Failure? loadNextPageFailure,
    bool clearLoadNextPageFailure = false,
    bool? isRefreshing,
  }) {
    return InspectionListLoaded(
      inspections ?? this.inspections,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      loadNextPageFailure: clearLoadNextPageFailure
          ? null
          : (loadNextPageFailure ?? this.loadNextPageFailure),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InspectionListLoaded) return false;
    if (other.page != page ||
        other.hasNext != hasNext ||
        other.isLoadingNextPage != isLoadingNextPage ||
        other.loadNextPageFailure != loadNextPageFailure ||
        other.isRefreshing != isRefreshing) {
      return false;
    }
    if (other.inspections.length != inspections.length) return false;
    for (var i = 0; i < inspections.length; i++) {
      if (other.inspections[i] != inspections[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(inspections),
    page,
    hasNext,
    isLoadingNextPage,
    loadNextPageFailure,
    isRefreshing,
  );
}
