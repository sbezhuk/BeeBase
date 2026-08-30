part of '../hive_form_cubit.dart';

mixin HiveFormEmitter on Cubit<HiveFormState> {
  Future<void> emitSubmit(
    IHiveWriter writer,
    HiveListRefreshNotifier refreshNotifier, {
    required String apiaryId,
    required Hive? initial,
    required String name,
    String? notes,
  }) async {
    emit(const HiveFormLoading());
    final result = initial == null
        ? await writer.createHive(apiaryId: apiaryId, name: name, notes: notes)
        : await writer.updateHive(
            apiaryId: apiaryId,
            id: initial.id,
            name: name,
            notes: notes,
          );
    result.fold((failure) => emit(HiveFormError(failure)), (hive) {
      refreshNotifier.notify();
      emit(HiveFormSuccess(hive));
    });
  }
}
