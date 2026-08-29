import 'package:beebase/core/offline/sync_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/sync_banner_state.dart';
part 'state/sync_banner_hidden.dart';
part 'state/sync_banner_available.dart';
part 'state/sync_banner_syncing.dart';
part 'mixin/sync_banner_emitter.dart';

/// Drives the app-wide "offline data available" banner. Global/singleton,
/// like [AuthenticationCubit] — one instance for the whole app lifetime, not
/// recreated per screen. Listens to [SyncEngine.syncAvailable] (a
/// `ValueListenable`, not a stream) and mirrors it to [SyncBannerHidden]/
/// [SyncBannerAvailable], ignoring changes while a manual [sync] is in
/// flight so per-operation status flips don't flicker the banner mid-sync.
class SyncBannerCubit extends Cubit<SyncBannerState> with SyncBannerEmitter {
  SyncBannerCubit({required this.engine}) : super(const SyncBannerHidden()) {
    emitFromAvailability(engine);
    engine.syncAvailable.addListener(_onAvailabilityChanged);
  }

  final SyncEngine engine;

  void _onAvailabilityChanged() {
    if (state is SyncBannerSyncing) return;
    emitFromAvailability(engine);
  }

  Future<void> sync() => emitSync(engine);

  /// Hides the banner locally without touching any pending data — it
  /// reappears the next time [SyncEngine.syncAvailable] flips (a fresh
  /// reconnect, or a newly enqueued operation), so the user can always
  /// synchronize later even after dismissing it.
  void dismiss() => emit(const SyncBannerHidden());

  @override
  Future<void> close() {
    engine.syncAvailable.removeListener(_onAvailabilityChanged);
    return super.close();
  }
}
