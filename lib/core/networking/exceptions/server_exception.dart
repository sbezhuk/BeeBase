/// Thrown for a 4xx/5xx response that carried a JSON error body
/// (`{"error": {"code", "message", "fields"?}}`, per the BeeBase API contract).
/// [message] is the server's own rendering, kept as a raw [String] here —
/// `ErrorText.server` decides whether [code] resolves it to a localised key
/// once this becomes a `ServerFailure`.
final class ServerException implements Exception {
  const ServerException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fields,
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, String>? fields;

  @override
  String toString() => 'ServerException($statusCode, $code, $message)';
}
