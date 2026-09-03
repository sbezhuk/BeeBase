part of '../profile_cubit.dart';

mixin ProfileEmitter on Cubit<ProfileState> {
  Future<void> emitLoad(
    IProfileReader reader,
    AuthenticationCubit authenticationCubit,
  ) async {
    final result = await reader.getProfile();
    result.fold((failure) => emit(ProfileError(failure)), (user) {
      authenticationCubit.setAuthenticated(user);
      emit(const ProfileLoaded());
    });
  }
}
