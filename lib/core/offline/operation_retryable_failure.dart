part of 'operation_result.dart';

/// A transient failure (no connectivity, timeout, 5xx) — `SyncEngine` will
/// retry this operation on the next sync attempt, up to its retry cap.
final class OperationRetryableFailure extends OperationResult {
  const OperationRetryableFailure(this.message);

  final String message;
}
