part of '../profile_edit_cubit.dart';

mixin ProfileEditEmitter on Cubit<ProfileEditState> {
  Future<void> emitSubmit(
    IProfileWriter writer,
    AuthenticationCubit authenticationCubit, {
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    bool removeAvatar = false,
  }) async {
    emit(const ProfileEditLoading());
    final result = await writer.updateProfile(
      firstName: firstName,
      lastName: lastName,
      newAvatarLocalFilePath: newAvatarLocalFilePath,
      removeAvatar: removeAvatar,
    );
    result.fold((failure) => emit(ProfileEditError(failure)), (profile) {
      final currentState = authenticationCubit.state;
      final baseUser = currentState is AuthenticationAuthenticated
          ? currentState.user
          : null;
      if (baseUser == null) {
        emit(
          const ProfileEditError(
            InternalFailure(ErrorTextKey('core.errors.no_active_session')),
          ),
        );
        return;
      }
      final mergedUser = profile.mergeOnto(baseUser);
      authenticationCubit.setAuthenticated(mergedUser);
      emit(ProfileEditSuccess(mergedUser));
    });
  }
}
