part of '../totp_setup_cubit.dart';

final class TotpSetupSuccess extends TotpSetupState {
  const TotpSetupSuccess(this.user);

  final User user;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is TotpSetupSuccess && other.user == user);

  @override
  int get hashCode => user.hashCode;
}
