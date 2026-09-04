part of '../login_otp_cubit.dart';

final class LoginOtpError extends LoginOtpState {
  const LoginOtpError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is LoginOtpError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
