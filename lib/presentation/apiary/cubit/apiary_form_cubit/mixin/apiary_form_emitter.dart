part of '../apiary_form_cubit.dart';

mixin ApiaryFormEmitter on Cubit<ApiaryFormState> {
  Future<void> emitSubmit(
    IApiaryWriter writer,
    ApiaryListRefreshNotifier refreshNotifier, {
    required Apiary? initial,
    required String name,
    String? description,
    String? location,
  }) async {
    emit(const ApiaryFormLoading());
    final result = initial == null
        ? await writer.createApiary(
            name: name,
            description: description,
            location: location,
          )
        : await writer.updateApiary(
            id: initial.id,
            name: name,
            description: description,
            location: location,
          );
    result.fold((failure) => emit(ApiaryFormError(failure)), (apiary) {
      refreshNotifier.notify();
      emit(ApiaryFormSuccess(apiary));
    });
  }
}
