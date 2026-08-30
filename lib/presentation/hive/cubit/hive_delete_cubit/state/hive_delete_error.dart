part of '../hive_delete_cubit.dart';

final class HiveDeleteError extends HiveDeleteState {
  const HiveDeleteError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiveDeleteError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
