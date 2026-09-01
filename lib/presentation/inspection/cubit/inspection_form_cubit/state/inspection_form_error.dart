part of '../inspection_form_cubit.dart';

final class InspectionFormError extends InspectionFormState {
  const InspectionFormError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InspectionFormError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
