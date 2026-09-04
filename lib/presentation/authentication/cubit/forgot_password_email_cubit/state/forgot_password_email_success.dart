part of '../forgot_password_email_cubit.dart';

final class ForgotPasswordEmailSuccess extends ForgotPasswordEmailState {
  const ForgotPasswordEmailSuccess(this.flow);

  final PasswordResetFlow flow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ForgotPasswordEmailSuccess && other.flow == flow);

  @override
  int get hashCode => flow.hashCode;
}
