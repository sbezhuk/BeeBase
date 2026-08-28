part of 'error_text.dart';

/// Text that is already final — a server message, or text from a platform
/// SDK. Never translated.
final class ErrorTextRaw extends ErrorText {
  const ErrorTextRaw(this.text);

  final String text;

  @override
  String resolve() => text;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ErrorTextRaw && other.text == text);

  @override
  int get hashCode => text.hashCode;
}
