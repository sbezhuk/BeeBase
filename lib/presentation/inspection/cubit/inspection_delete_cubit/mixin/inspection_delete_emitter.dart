part of '../inspection_delete_cubit.dart';

mixin InspectionDeleteEmitter on Cubit<InspectionDeleteState> {
  Future<void> emitDelete(
    IInspectionWriter writer,
    InspectionListRefreshNotifier refreshNotifier, {
    required String hiveId,
    required String id,
  }) async {
    emit(const InspectionDeleteLoading());
    final result = await writer.deleteInspection(hiveId: hiveId, id: id);
    result.fold((failure) => emit(InspectionDeleteError(failure)), (_) {
      refreshNotifier.notify();
      emit(const InspectionDeleteSuccess());
    });
  }
}
