part of '../dashboard_cubit.dart';

/// One dashboard section's independent load state — [DashboardLoaded] holds
/// four of these (overview/apiary/inspection/recent-activity) so a failure
/// in one section never blanks the others (see BEEB-24's per-section error
/// isolation requirement).
sealed class DashboardSection<T> {
  const DashboardSection();
}

final class SectionLoading<T> extends DashboardSection<T> {
  const SectionLoading();

  @override
  bool operator ==(Object other) => other is SectionLoading<T>;

  @override
  int get hashCode => (SectionLoading<T>).hashCode;
}

final class SectionData<T> extends DashboardSection<T> {
  const SectionData(this.value);

  final T value;

  // Equality here is only as deep as [T]'s own `==` — for a `List`-typed
  // [T] (recentActivity's `List<ActivityItem>`) that's reference equality,
  // since Dart's default `List.==` doesn't compare elements. Tests covering
  // that section compare its contents with a `having`/predicate matcher
  // rather than relying on `SectionData` equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SectionData<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

final class SectionError<T> extends DashboardSection<T> {
  const SectionError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SectionError<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
