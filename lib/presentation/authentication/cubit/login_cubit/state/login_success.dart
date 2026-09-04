part of '../login_cubit.dart';

final class LoginSuccess extends LoginState {
  const LoginSuccess(this.challenge);

  final AuthChallenge challenge;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is LoginSuccess && other.challenge == challenge);

  @override
  int get hashCode => challenge.hashCode;
}
