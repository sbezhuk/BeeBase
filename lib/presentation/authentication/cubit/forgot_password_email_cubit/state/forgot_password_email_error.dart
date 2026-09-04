part of '../forgot_password_email_cubit.dart';

final class ForgotPasswordEmailError extends ForgotPasswordEmailState {
  const ForgotPasswordEmailError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ForgotPasswordEmailError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
