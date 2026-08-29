import 'dart:async';

import 'package:beebase/core/services/connectivity_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/connectivity_state.dart';
part 'state/connectivity_online.dart';
part 'state/connectivity_offline.dart';
part 'mixin/connectivity_emitter.dart';

/// Drives every connectivity-dependent UI decision app-wide — the "you're
/// offline" banner ([ConnectivityBanner]) and gating the apiary delete
/// button on a synced entity. Global/singleton, like [SyncBannerCubit]: one
/// instance for the whole app lifetime, not recreated per screen. Starts
/// optimistically [ConnectivityOnline] (so nothing flashes an offline state
/// before the first check resolves), corrected by the one-shot
/// [IConnectivityService.isOnline] check and kept current by
/// [IConnectivityService.status] from then on.
class ConnectivityCubit extends Cubit<ConnectivityState> with ConnectivityEmitter {
  ConnectivityCubit({required this.connectivity}) : super(const ConnectivityOnline()) {
    _subscription = connectivity.status.listen(emitFromOnline);
    unawaited(connectivity.isOnline.then(emitFromOnline));
  }

  final IConnectivityService connectivity;
  StreamSubscription<bool>? _subscription;

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    return super.close();
  }
}
