import 'package:beebase/core/offline/sync_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/sync_banner_state.dart';
part 'state/sync_banner_hidden.dart';
part 'state/sync_banner_available.dart';
part 'state/sync_banner_syncing.dart';
part 'mixin/sync_banner_emitter.dart';

/// Drives the app-wide "offline data available" banner. Global/singleton,
/// like [AuthenticationCubit] — one instance for the whole app lifetime, not
/// recreated per screen. Mirrors [SyncEngine.isSyncing]/[SyncEngine.
/// syncAvailable] to [SyncBannerSyncing]/[SyncBannerAvailable]/
/// [SyncBannerHidden] — [isSyncing] takes priority whenever it's true, which
/// is what keeps the banner showing one continuous loader for the whole
/// sync (see [SyncBannerEmitter.emitFromEngine]) rather than something this
/// cubit has to track locally around a `syncNow()` call itself.
class SyncBannerCubit extends Cubit<SyncBannerState> with SyncBannerEmitter {
  SyncBannerCubit({required this.engine}) : super(const SyncBannerHidden()) {
    emitFromEngine(engine);
    engine.syncAvailable.addListener(_onChanged);
    engine.isSyncing.addListener(_onChanged);
  }

  final SyncEngine engine;

  void _onChanged() => emitFromEngine(engine);

  /// The only place `syncNow()` is ever called from this cubit — and,
  /// short of the Profile screen's sync row calling it directly, the only
  /// place at all: synchronization is exclusively user-initiated (see
  /// `SyncEngine`'s own doc). This method itself no longer manages the
  /// `Syncing` state around the call — `_onChanged` reacting to
  /// [SyncEngine.isSyncing] does that instead, so it stays correct even if
  /// something else ever called `syncNow()` too.
  Future<void> sync() => engine.syncNow();

  /// Hides the banner locally without touching any pending data — it
  /// reappears the next time [SyncEngine.syncAvailable] flips (a fresh
  /// reconnect, or a newly enqueued operation), so the user can always
  /// synchronize later even after dismissing it.
  void dismiss() => emit(const SyncBannerHidden());

  @override
  Future<void> close() {
    engine.syncAvailable.removeListener(_onChanged);
    engine.isSyncing.removeListener(_onChanged);
    return super.close();
  }
}
