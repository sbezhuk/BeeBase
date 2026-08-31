part of '../apiary_form_cubit.dart';

mixin ApiaryFormEmitter on Cubit<ApiaryFormState> {
  Future<void> emitSubmit(
    IApiaryWriter writer,
    ApiaryListRefreshNotifier refreshNotifier,
    MediaGalleryCubit? mediaGalleryCubit, {
    required Apiary? initial,
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    emit(const ApiaryFormLoading());
    final result = initial == null
        ? await writer.createApiary(name: name, description: description, location: location, lat: lat, lon: lon)
        : await writer.updateApiary(id: initial.id, name: name, description: description, location: location, lat: lat, lon: lon);
    await result.fold((failure) async => emit(ApiaryFormError(failure)), (apiary) async {
      if (mediaGalleryCubit != null && mediaGalleryCubit.hasStagedPhotos) {
        await mediaGalleryCubit.attachTo(MediaOwnerType.apiary, apiary.id);
      }
      refreshNotifier.notify();
      emit(ApiaryFormSuccess(apiary));
    });
  }
}
