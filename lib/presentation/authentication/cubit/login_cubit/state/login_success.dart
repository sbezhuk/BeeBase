part of '../login_cubit.dart';

final class LoginSuccess extends LoginState {
  const LoginSuccess(this.user);

  final User user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LoginSuccess && other.user == user);

  @override
  int get hashCode => user.hashCode;
}
