part of '../register_cubit.dart';

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess(this.user);

  final User user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegisterSuccess && other.user == user);

  @override
  int get hashCode => user.hashCode;
}
