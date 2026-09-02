part of '../hive_form_cubit.dart';

mixin HiveFormEmitter on Cubit<HiveFormState> {
  Future<void> emitSubmit(
    IHiveWriter writer,
    HiveListRefreshNotifier refreshNotifier,
    MediaGalleryCubit? mediaGalleryCubit, {
    required String apiaryId,
    required Hive? initial,
    required String name,
    String? notes,
  }) async {
    emit(const HiveFormLoading());
    final result = initial == null
        ? await writer.createHive(apiaryId: apiaryId, name: name, notes: notes)
        : await writer.updateHive(apiaryId: apiaryId, id: initial.id, name: name, notes: notes);
    await result.fold((failure) async => emit(HiveFormError(failure)), (hive) async {
      if (mediaGalleryCubit != null && mediaGalleryCubit.hasPendingChanges) {
        await mediaGalleryCubit.commitChanges(MediaOwnerType.hive, hive.id);
      }
      refreshNotifier.notify();
      emit(HiveFormSuccess(hive));
    });
  }
}
