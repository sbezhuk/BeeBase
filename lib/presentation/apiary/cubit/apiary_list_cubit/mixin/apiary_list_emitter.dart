part of '../apiary_list_cubit.dart';

mixin ApiaryListEmitter on Cubit<ApiaryListState> {
  Future<void> emitLoadApiaries(IApiaryReader reader) async {
    emit(const ApiaryListLoading());
    await _fetch(reader);
  }

  Future<void> emitRefreshApiaries(IApiaryReader reader) => _fetch(reader);

  Future<void> _fetch(IApiaryReader reader) async {
    final result = await reader.getApiaries();
    result.fold((failure) => emit(ApiaryListError(failure)), (apiaries) => emit(ApiaryListLoaded(apiaries)));
  }
}
