part of '../totp_setup_cubit.dart';

mixin TotpSetupEmitter on Cubit<TotpSetupState> {
  Future<void> emitVerify(
    AuthenticationRepository repository,
    AuthenticationCubit authenticationCubit, {
    required String setupToken,
    required String otp,
  }) async {
    emit(const TotpSetupLoading());
    final result = await repository.verifyTotpSetup(setupToken: setupToken, otp: otp);
    result.fold((failure) => emit(TotpSetupError(failure)), (user) {
      authenticationCubit.setAuthenticated(user);
      emit(TotpSetupSuccess(user));
    });
  }
}
