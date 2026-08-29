part 'operation_success.dart';
part 'operation_retryable_failure.dart';
part 'operation_permanent_failure.dart';
part 'operation_superseded.dart';

/// Outcome of [OperationHandler.handle] — the classification `SyncEngine`
/// uses to decide whether to retry, give up, or mark an operation synced,
/// without knowing anything about what the operation actually did.
sealed class OperationResult {
  const OperationResult();
}
