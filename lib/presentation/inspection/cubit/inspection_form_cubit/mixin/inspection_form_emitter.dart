part of '../inspection_form_cubit.dart';

mixin InspectionFormEmitter on Cubit<InspectionFormState> {
  Future<void> emitSubmit(
    IInspectionWriter writer,
    InspectionListRefreshNotifier refreshNotifier, {
    required String hiveId,
    required Inspection? initial,
    required DateTime date,
    required InspectionType type,
    String? notes,
  }) async {
    emit(const InspectionFormLoading());
    final result = initial == null
        ? await writer.createInspection(hiveId: hiveId, date: date, type: type, notes: notes)
        : await writer.updateInspection(
            hiveId: hiveId,
            id: initial.id,
            date: date,
            type: type,
            notes: notes,
          );
    result.fold((failure) => emit(InspectionFormError(failure)), (inspection) {
      refreshNotifier.notify();
      emit(InspectionFormSuccess(inspection));
    });
  }
}
