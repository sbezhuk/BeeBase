part of '../hive_delete_cubit.dart';

mixin HiveDeleteEmitter on Cubit<HiveDeleteState> {
  Future<void> emitDelete(
    IHiveWriter writer,
    HiveListRefreshNotifier refreshNotifier,
    String id,
  ) async {
    emit(const HiveDeleteLoading());
    final result = await writer.deleteHive(id);
    result.fold((failure) => emit(HiveDeleteError(failure)), (_) {
      refreshNotifier.notify();
      emit(const HiveDeleteSuccess());
    });
  }
}
