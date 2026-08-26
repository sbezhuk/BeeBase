part of 'error_text.dart';

/// A key into `assets/langs/*.json`, translated on display.
final class ErrorTextKey extends ErrorText {
  const ErrorTextKey(this.key);

  final String key;

  @override
  String resolve() => key.tr();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ErrorTextKey && other.key == key);

  @override
  int get hashCode => key.hashCode;
}
