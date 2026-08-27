part of '../apiary_form_cubit.dart';

final class ApiaryFormError extends ApiaryFormState {
  const ApiaryFormError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiaryFormError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
