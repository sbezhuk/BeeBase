part of '../hive_form_cubit.dart';

final class HiveFormError extends HiveFormState {
  const HiveFormError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiveFormError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
