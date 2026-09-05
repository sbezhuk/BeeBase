import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class INetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

final class NetworkInfo implements INetworkInfo {
  NetworkInfo({Connectivity? connectivity, this.lookupHost = 'google.com'}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final String lookupHost;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _lastKnownState;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _notifyIfChanged(false);
      return false;
    }

    try {
      final result = await InternetAddress.lookup(lookupHost).timeout(const Duration(seconds: 3));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _notifyIfChanged(connected);
      return connected;
    } catch (_) {
      _notifyIfChanged(false);
      return false;
    }
  }

  void startMonitoring() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _notifyIfChanged(false);
      } else {
        await isConnected;
      }
    });
  }

  void _notifyIfChanged(bool connected) {
    if (_lastKnownState != connected) {
      _lastKnownState = connected;
      if (!_controller.isClosed) {
        _controller.add(connected);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
