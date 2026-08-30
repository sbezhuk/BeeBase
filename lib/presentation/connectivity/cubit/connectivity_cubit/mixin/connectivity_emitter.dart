part of '../connectivity_cubit.dart';

mixin ConnectivityEmitter on Cubit<ConnectivityState> {
  // Guards against the one-shot `isOnline` check (kicked off in the
  // constructor, awaited via `unawaited`) resolving after `close()` was
  // already called — e.g. a cubit closed almost immediately after creation —
  // which would otherwise throw "Cannot emit new states after calling close".
  void emitFromOnline(bool online) {
    if (isClosed) return;
    emit(online ? const ConnectivityOnline() : const ConnectivityOffline());
  }
}
