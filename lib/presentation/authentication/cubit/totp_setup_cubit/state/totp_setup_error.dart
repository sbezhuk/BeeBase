part of '../totp_setup_cubit.dart';

final class TotpSetupError extends TotpSetupState {
  const TotpSetupError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is TotpSetupError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
