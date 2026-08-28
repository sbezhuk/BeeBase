part of 'operation_result.dart';

/// A failure that will never succeed no matter how many times it's retried
/// (validation, auth, a business rule rejection) — `SyncEngine` marks the
/// operation `failed` immediately and does not retry it.
final class OperationPermanentFailure extends OperationResult {
  const OperationPermanentFailure(this.message);

  final String message;
}
