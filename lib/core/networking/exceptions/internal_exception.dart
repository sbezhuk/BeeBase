import 'package:beebase/core/error/error_text.dart';

/// Thrown for everything else: no connection, malformed responses, 5xx without
/// a parseable body, unexpected errors.
final class InternalException implements Exception {
  const InternalException(this.message);

  final ErrorText message;

  @override
  String toString() => 'InternalException($message)';
}
