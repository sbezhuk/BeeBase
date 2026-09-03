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
    result.fold((failure) => emit(ProfileEditError(failure)), (user) {
      authenticationCubit.setAuthenticated(user);
      emit(ProfileEditSuccess(user));
    });
  }
}
