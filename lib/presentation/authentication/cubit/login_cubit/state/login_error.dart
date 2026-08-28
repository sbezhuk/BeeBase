part of '../login_cubit.dart';

final class LoginError extends LoginState {
  const LoginError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is LoginError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
