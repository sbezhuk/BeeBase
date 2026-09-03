part of '../sync_banner_cubit.dart';

mixin SyncBannerEmitter on Cubit<SyncBannerState> {
  /// [SyncEngine.isSyncing] is the single authoritative "a sync batch is
  /// running" signal — it stays `true` for the *entire* [SyncEngine.syncNow]
  /// call, across every entity and every in-pass retry, so deriving state
  /// from it (rather than emitting [SyncBannerSyncing] locally around the
  /// `syncNow()` call) is what keeps this banner showing one continuous
  /// loader for the whole process instead of one that could flicker per
  /// operation.
  void emitFromEngine(SyncEngine engine) {
    if (engine.isSyncing.value) {
      emit(const SyncBannerSyncing());
    } else {
      emit(
        engine.syncAvailable.value
            ? const SyncBannerAvailable()
            : const SyncBannerHidden(),
      );
    }
  }
}
