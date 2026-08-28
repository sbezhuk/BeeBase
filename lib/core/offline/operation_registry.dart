import 'package:beebase/core/offline/operation_handler.dart';

/// Looks up the [OperationHandler] for an operation's entity type. Adding
/// offline support to a new feature means adding one more entry to the map
/// this is built from (see `di.dart`) — never touching `SyncEngine`.
final class OperationRegistry {
  const OperationRegistry(this._handlers);

  final Map<String, OperationHandler> _handlers;

  OperationHandler? handlerFor(String entityType) => _handlers[entityType];
}
