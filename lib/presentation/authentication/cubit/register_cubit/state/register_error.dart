part of '../register_cubit.dart';

final class RegisterError extends RegisterState {
  const RegisterError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is RegisterError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
