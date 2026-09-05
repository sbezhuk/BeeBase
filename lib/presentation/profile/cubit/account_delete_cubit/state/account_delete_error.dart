part of '../account_delete_cubit.dart';

final class AccountDeleteError extends AccountDeleteState {
  const AccountDeleteError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountDeleteError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
