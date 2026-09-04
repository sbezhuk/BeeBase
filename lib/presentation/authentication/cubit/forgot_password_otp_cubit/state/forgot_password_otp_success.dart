part of '../forgot_password_otp_cubit.dart';

final class ForgotPasswordOtpSuccess extends ForgotPasswordOtpState {
  const ForgotPasswordOtpSuccess(this.verification);

  final PasswordResetVerification verification;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ForgotPasswordOtpSuccess && other.verification == verification);

  @override
  int get hashCode => verification.hashCode;
}
