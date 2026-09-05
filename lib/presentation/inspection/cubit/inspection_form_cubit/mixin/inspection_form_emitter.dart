part of '../inspection_form_cubit.dart';

mixin InspectionFormEmitter on Cubit<InspectionFormState> {
  Future<void> emitSubmit(
    IInspectionWriter writer,
    InspectionListRefreshNotifier refreshNotifier,
    MediaGalleryCubit? mediaGalleryCubit, {
    required String hiveId,
    required Inspection? initial,
    required DateTime date,
    required InspectionType type,
    required String notes,
  }) async {
    emit(const InspectionFormLoading());
    final result = initial == null
        ? await writer.createInspection(hiveId: hiveId, date: date, type: type, notes: notes)
        : await writer.updateInspection(hiveId: hiveId, id: initial.id, date: date, type: type, notes: notes);
    await result.fold((failure) async => emit(InspectionFormError(failure)), (inspection) async {
      if (mediaGalleryCubit != null && mediaGalleryCubit.hasPendingChanges) {
        await mediaGalleryCubit.commitChanges(MediaOwnerType.inspection, inspection.id);
      }
      refreshNotifier.notify();
      emit(InspectionFormSuccess(inspection));
    });
  }
}
