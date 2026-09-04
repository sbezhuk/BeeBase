part of '../reset_password_cubit.dart';

mixin ResetPasswordEmitter on Cubit<ResetPasswordState> {
  Future<void> emitConfirm(
    IPasswordResetFlow repository, {
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    emit(const ResetPasswordLoading());
    final result = await repository.confirmPasswordReset(
      resetToken: resetToken,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    result.fold((failure) => emit(ResetPasswordError(failure)), (_) => emit(const ResetPasswordSuccess()));
  }
}
