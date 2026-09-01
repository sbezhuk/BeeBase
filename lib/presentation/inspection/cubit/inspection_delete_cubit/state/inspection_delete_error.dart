part of '../inspection_delete_cubit.dart';

final class InspectionDeleteError extends InspectionDeleteState {
  const InspectionDeleteError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InspectionDeleteError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
