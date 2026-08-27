part of '../apiary_delete_cubit.dart';

mixin ApiaryDeleteEmitter on Cubit<ApiaryDeleteState> {
  Future<void> emitDelete(
    IApiaryWriter writer,
    ApiaryListRefreshNotifier refreshNotifier,
    String id,
  ) async {
    emit(const ApiaryDeleteLoading());
    final result = await writer.deleteApiary(id);
    result.fold((failure) => emit(ApiaryDeleteError(failure)), (_) {
      refreshNotifier.notify();
      emit(const ApiaryDeleteSuccess());
    });
  }
}
