part of '../change_password_cubit.dart';

mixin ChangePasswordEmitter on Cubit<ChangePasswordState> {
  Future<void> emitSubmit(
    IPasswordChanger repository,
    AuthenticationCubit authenticationCubit, {
    required String currentPassword,
    required String newPassword,
    required String otp,
  }) async {
    emit(const ChangePasswordLoading());
    final result = await repository.changePassword(currentPassword: currentPassword, newPassword: newPassword, otp: otp);
    await result.fold((failure) async => emit(ChangePasswordError(failure)), (_) async {
      emit(const ChangePasswordSuccess());
      await authenticationCubit.logout();
    });
  }
}
