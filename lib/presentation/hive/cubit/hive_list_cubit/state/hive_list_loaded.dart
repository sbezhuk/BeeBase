part of '../hive_list_cubit.dart';

final class HiveListLoaded extends HiveListState {
  const HiveListLoaded(
    this.hives, {
    this.page = PaginationDefaults.firstPage,
    this.hasNext = false,
    this.isLoadingNextPage = false,
    this.loadNextPageFailure,
  });

  final List<Hive> hives;

  /// The page most recently fetched into [hives] — the next "load more"
  /// call requests `page + 1`.
  final int page;
  final bool hasNext;

  /// True while a "load more" request is in flight — guards against a
  /// duplicate request firing (e.g. from rapid scrolling) before the
  /// current one resolves.
  final bool isLoadingNextPage;

  /// Set when the most recent "load more" attempt failed. [hives] is left
  /// untouched so already-loaded items never disappear because the next
  /// page failed to load.
  final Failure? loadNextPageFailure;

  bool get isEmpty => hives.isEmpty;

  HiveListLoaded copyWith({
    List<Hive>? hives,
    int? page,
    bool? hasNext,
    bool? isLoadingNextPage,
    Failure? loadNextPageFailure,
    bool clearLoadNextPageFailure = false,
  }) {
    return HiveListLoaded(
      hives ?? this.hives,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      loadNextPageFailure: clearLoadNextPageFailure
          ? null
          : (loadNextPageFailure ?? this.loadNextPageFailure),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HiveListLoaded) return false;
    if (other.page != page ||
        other.hasNext != hasNext ||
        other.isLoadingNextPage != isLoadingNextPage ||
        other.loadNextPageFailure != loadNextPageFailure) {
      return false;
    }
    if (other.hives.length != hives.length) return false;
    for (var i = 0; i < hives.length; i++) {
      if (other.hives[i] != hives[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(hives),
    page,
    hasNext,
    isLoadingNextPage,
    loadNextPageFailure,
  );
}
