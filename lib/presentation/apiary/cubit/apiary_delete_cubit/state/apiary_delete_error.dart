part of '../apiary_delete_cubit.dart';

final class ApiaryDeleteError extends ApiaryDeleteState {
  const ApiaryDeleteError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ApiaryDeleteError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
