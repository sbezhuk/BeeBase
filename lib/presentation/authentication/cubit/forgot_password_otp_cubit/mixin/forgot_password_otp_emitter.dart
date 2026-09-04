part of '../forgot_password_otp_cubit.dart';

mixin ForgotPasswordOtpEmitter on Cubit<ForgotPasswordOtpState> {
  Future<void> emitVerify(IPasswordResetFlow repository, {required String flowToken, required String otp}) async {
    emit(const ForgotPasswordOtpLoading());
    final result = await repository.verifyPasswordResetOtp(flowToken: flowToken, otp: otp);
    result.fold(
      (failure) => emit(ForgotPasswordOtpError(failure)),
      (verification) => emit(ForgotPasswordOtpSuccess(verification)),
    );
  }
}
