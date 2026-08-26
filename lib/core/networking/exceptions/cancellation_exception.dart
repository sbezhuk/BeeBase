import 'package:beebase/core/error/error_text.dart';

/// Thrown for timeouts, cancellations, and bad-certificate errors.
final class CancellationException implements Exception {
  const CancellationException(this.message);

  final ErrorText message;

  @override
  String toString() => 'CancellationException($message)';
}
