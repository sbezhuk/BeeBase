import 'package:beebase/core/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final class ConnectivityService implements IConnectivityService {
  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async => _isOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get status => _connectivity.onConnectivityChanged.map(_isOnline);

  bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((result) => result == ConnectivityResult.none);
}
