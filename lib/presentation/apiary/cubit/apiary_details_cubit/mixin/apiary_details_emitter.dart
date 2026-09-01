part of '../apiary_details_cubit.dart';

mixin ApiaryDetailsEmitter on Cubit<ApiaryDetailsState> {
  // Guards against a refresh-notifier callback or the edit-form return
  // resolving after `close()` was already called (page popped mid-flight),
  // which would otherwise throw "Cannot emit new states after calling
  // close".
  void emitLoaded(Apiary apiary, {int? hiveCount}) {
    if (isClosed) return;
    emit(ApiaryDetailsLoaded(apiary, hiveCount: hiveCount ?? state.hiveCount));
  }
}
