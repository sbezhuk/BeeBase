part of '../change_password_cubit.dart';

final class ChangePasswordError extends ChangePasswordState {
  const ChangePasswordError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ChangePasswordError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
