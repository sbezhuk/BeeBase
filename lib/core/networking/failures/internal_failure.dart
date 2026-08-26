part of 'failure.dart';

/// No connection, malformed response, or an unexpected error.
final class InternalFailure extends Failure {
  const InternalFailure(super.message);
}
