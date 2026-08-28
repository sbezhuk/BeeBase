part of '../apiary_list_cubit.dart';

final class ApiaryListError extends ApiaryListState {
  const ApiaryListError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ApiaryListError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
