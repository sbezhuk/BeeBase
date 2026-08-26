part of 'failure.dart';

/// The server responded with a JSON error body. `code` is the stable,
/// machine-readable key returned by the API (e.g. `invalid_credentials`) —
/// [message] resolves it via [ErrorText.server], never displaying it raw.
final class ServerFailure extends Failure {
  ServerFailure({required this.code, required String message, this.fields})
    : super(ErrorText.server(code: code, message: message));

  final String code;
  final Map<String, String>? fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ServerFailure && other.code == code && other.message == message);

  @override
  int get hashCode => Object.hash(code, message);
}
