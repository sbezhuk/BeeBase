part of '../register_cubit.dart';

mixin RegisterEmitter on Cubit<RegisterState> {
  Future<void> emitRegister(
    AuthenticationRepository repository,
    AuthenticationCubit authenticationCubit, {
    required String email,
    required String password,
  }) async {
    emit(const RegisterLoading());
    final result = await repository.register(email: email, password: password);
    result.fold((failure) => emit(RegisterError(failure)), (user) {
      authenticationCubit.setAuthenticated(user);
      emit(RegisterSuccess(user));
    });
  }
}
