import 'package:beebase/core/error/error_text.dart';

part 'server_failure.dart';
part 'internal_failure.dart';
part 'cancellation_failure.dart';

sealed class Failure {
  const Failure(this.message);

  final ErrorText message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Failure && other.message == message);

  @override
  int get hashCode => message.hashCode;
}
