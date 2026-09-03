part of '../profile_cubit.dart';

mixin ProfileEmitter on Cubit<ProfileState> {
  Future<void> emitLoad(IProfileReader reader, AuthenticationCubit authenticationCubit) async {
    final result = await reader.getProfile();
    result.fold((failure) => emit(ProfileError(failure)), (profile) {
      final currentState = authenticationCubit.state;
      if (currentState is AuthenticationAuthenticated) {
        authenticationCubit.setAuthenticated(profile.mergeOnto(currentState.user));
      }
      emit(const ProfileLoaded());
    });
  }
}
