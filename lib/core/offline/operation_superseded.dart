part of 'operation_result.dart';

/// The request succeeded, but a newer local edit was consolidated into this
/// operation's row while the request was in flight, so what the server
/// received is already stale. The handler has already re-targeted the row
/// (new payload/identity as needed) and left it `pending` for another sync
/// pass — `SyncEngine` must not mark it `synced` on this result.
final class OperationSuperseded extends OperationResult {
  const OperationSuperseded();
}
