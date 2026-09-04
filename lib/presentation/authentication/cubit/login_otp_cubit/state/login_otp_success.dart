part of '../login_otp_cubit.dart';

final class LoginOtpSuccess extends LoginOtpState {
  const LoginOtpSuccess(this.user);

  final User user;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is LoginOtpSuccess && other.user == user);

  @override
  int get hashCode => user.hashCode;
}
