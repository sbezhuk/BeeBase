part of '../forgot_password_email_cubit.dart';

mixin ForgotPasswordEmailEmitter on Cubit<ForgotPasswordEmailState> {
  Future<void> emitSubmit(IPasswordResetFlow repository, {required String email}) async {
    emit(const ForgotPasswordEmailLoading());
    final result = await repository.requestPasswordReset(email: email);
    result.fold(
      (failure) => emit(ForgotPasswordEmailError(failure)),
      (flow) => emit(ForgotPasswordEmailSuccess(flow)),
    );
  }
}
