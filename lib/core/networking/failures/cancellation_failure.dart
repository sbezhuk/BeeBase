part of 'failure.dart';

/// A request timed out or was cancelled.
final class CancellationFailure extends Failure {
  const CancellationFailure(super.message);
}
