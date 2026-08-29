part of '../sync_banner_cubit.dart';

mixin SyncBannerEmitter on Cubit<SyncBannerState> {
  void emitFromAvailability(SyncEngine engine) {
    emit(engine.syncAvailable.value ? const SyncBannerAvailable() : const SyncBannerHidden());
  }

  Future<void> emitSync(SyncEngine engine) async {
    emit(const SyncBannerSyncing());
    await engine.syncNow();
    emitFromAvailability(engine);
  }
}
