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
      identical(this, other) ||
      (other is ServerFailure &&
          other.code == code &&
          other.message == message);

  @override
  int get hashCode => Object.hash(code, message);

  // Surfaces `code`/`fields` — the actual machine-readable reason the
  // server rejected the request — in any `$failure`/debugPrint log. Without
  // this, logging a `ServerFailure` printed only "Instance of
  // 'ServerFailure'", which made a validation rejection (e.g. a sync
  // operation failing with a generic "please check the highlighted fields")
  // impossible to diagnose from the logs alone: `code` names the rule that
  // tripped and `fields` names which field(s), whereas [message] alone is
  // only ever the generic, user-facing translation of `code`.
  @override
  String toString() =>
      'ServerFailure(code: $code, fields: $fields, message: $message)';
}
