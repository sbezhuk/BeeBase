part of '../register_cubit.dart';

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess(this.challenge);

  final TotpSetupChallenge challenge;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RegisterSuccess && other.challenge == challenge);

  @override
  int get hashCode => challenge.hashCode;
}
