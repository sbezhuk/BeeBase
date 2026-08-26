import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/extension/server_failure_message_extension.dart';

/// Field names the login/register forms accept per-field validation errors
/// for. Matches the keys the API sends in a [ServerFailure]'s `fields` map.
enum AuthField { email, password }

/// Per-field validation copy for the login/register forms, read out of a
/// [ServerFailure]'s generic `fields` map by [AuthField] name.
final class AuthFieldErrors {
  const AuthFieldErrors({this.email, this.password});

  factory AuthFieldErrors.fromFailure(Failure failure) {
    final fields = failure is ServerFailure ? failure.fields : null;
    return AuthFieldErrors(
      email: fields?[AuthField.email.name]?.authFieldErrorMessage,
      password: fields?[AuthField.password.name]?.authFieldErrorMessage,
    );
  }

  final String? email;
  final String? password;

  bool get hasErrors => email != null || password != null;
}
