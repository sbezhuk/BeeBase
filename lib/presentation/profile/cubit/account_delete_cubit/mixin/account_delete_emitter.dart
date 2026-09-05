part of '../account_delete_cubit.dart';

mixin AccountDeleteEmitter on Cubit<AccountDeleteState> {
  Future<void> emitDelete(
    IAccountDeleter deleter,
    AuthenticationCubit authenticationCubit, {
    required String otp,
  }) async {
    emit(const AccountDeleteLoading());
    final result = await deleter.deleteAccount(otp: otp);
    result.fold((failure) => emit(AccountDeleteError(failure)), (_) {
      // Emit success before handing off to `logout()` — that call flips
      // `AuthenticationCubit` to unauthenticated, which the app-level
      // listener (see `Application`) reacts to by replacing the whole
      // route stack, tearing this cubit down. Emitting first, while it's
      // still open, avoids racing that teardown.
      emit(const AccountDeleteSuccess());
      unawaited(authenticationCubit.logout());
    });
  }
}
