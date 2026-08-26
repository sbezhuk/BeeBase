part of '../authentication_cubit.dart';

final class AuthenticationAuthenticated extends AuthenticationState {
  const AuthenticationAuthenticated(this.user);

  final User user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthenticationAuthenticated && other.user == user);

  @override
  int get hashCode => user.hashCode;
}
