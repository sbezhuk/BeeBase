part of '../reset_password_cubit.dart';

final class ResetPasswordError extends ResetPasswordState {
  const ResetPasswordError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ResetPasswordError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
