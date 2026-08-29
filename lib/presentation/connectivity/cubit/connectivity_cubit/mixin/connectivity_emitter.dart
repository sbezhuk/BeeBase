part of '../connectivity_cubit.dart';

mixin ConnectivityEmitter on Cubit<ConnectivityState> {
  void emitFromOnline(bool online) {
    emit(online ? const ConnectivityOnline() : const ConnectivityOffline());
  }
}
