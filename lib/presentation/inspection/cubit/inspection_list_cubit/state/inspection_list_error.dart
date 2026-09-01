part of '../inspection_list_cubit.dart';

final class InspectionListError extends InspectionListState {
  const InspectionListError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InspectionListError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
