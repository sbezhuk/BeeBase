part of '../authentication_cubit.dart';

mixin AuthenticationEmitter on Cubit<AuthenticationState> {
  Future<void> emitRestoreSession(AuthenticationRepository repository) async {
    final result = await repository.restoreSession();
    result.fold(
      (failure) => emit(const AuthenticationUnauthenticated()),
      (user) => emit(AuthenticationAuthenticated(user)),
    );
  }

  Future<void> emitLogout(AuthenticationRepository repository) async {
    await repository.logout();
    emit(const AuthenticationUnauthenticated());
  }
}
