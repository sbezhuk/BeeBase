/// Application-level abstraction over network reachability. Feature code
/// depends on this, never on a connectivity package directly.
abstract interface class IConnectivityService {
  Future<bool> get isOnline;

  Stream<bool> get status;
}
