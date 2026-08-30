part of '../hive_list_cubit.dart';

final class HiveListError extends HiveListState {
  const HiveListError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiveListError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
