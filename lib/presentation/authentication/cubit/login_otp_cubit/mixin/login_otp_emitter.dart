part of '../login_otp_cubit.dart';

mixin LoginOtpEmitter on Cubit<LoginOtpState> {
  Future<void> emitVerify(
    AuthenticationRepository repository,
    AuthenticationCubit authenticationCubit, {
    required String challengeToken,
    required String otp,
  }) async {
    emit(const LoginOtpLoading());
    final result = await repository.verifyLoginOtp(challengeToken: challengeToken, otp: otp);
    result.fold((failure) => emit(LoginOtpError(failure)), (user) {
      authenticationCubit.setAuthenticated(user);
      emit(LoginOtpSuccess(user));
    });
  }
}
