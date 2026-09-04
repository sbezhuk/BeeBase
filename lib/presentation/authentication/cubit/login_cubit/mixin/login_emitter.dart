part of '../login_cubit.dart';

mixin LoginEmitter on Cubit<LoginState> {
  Future<void> emitLogin(AuthenticationRepository repository, {required String email, required String password}) async {
    emit(const LoginLoading());
    final result = await repository.login(email: email, password: password);
    result.fold((failure) => emit(LoginError(failure)), (challenge) => emit(LoginSuccess(challenge)));
  }
}
