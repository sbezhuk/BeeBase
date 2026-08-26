import 'dart:async';

/// Cross-cutting event bus for session lifecycle events that originate
/// outside the widget tree — namely the networking layer discovering, via a
/// failed token refresh, that the session is no longer valid. Consumers
/// (the global authentication cubit) listen to react by signing the user out.
class SessionService {
  final _sessionExpiredController = StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  void notifySessionExpired() => _sessionExpiredController.add(null);
}
