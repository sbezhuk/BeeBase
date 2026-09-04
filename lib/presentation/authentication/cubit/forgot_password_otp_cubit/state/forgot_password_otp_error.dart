part of '../forgot_password_otp_cubit.dart';

final class ForgotPasswordOtpError extends ForgotPasswordOtpState {
  const ForgotPasswordOtpError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ForgotPasswordOtpError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
