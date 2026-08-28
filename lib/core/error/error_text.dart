import 'package:easy_localization/easy_localization.dart';

part 'error_text_key.dart';
part 'error_text_raw.dart';

const String _kServerErrorPrefix = 'server.errors';

/// Text shown to the user when something fails.
///
/// Error text reaches the UI from two incompatible sources: localisation keys
/// the app owns, and messages the server (or a platform SDK) already
/// rendered in its own words. Both used to travel as a bare [String], so the
/// UI translated both — which silently mistranslated nothing and translated
/// server text into itself.
///
/// The variants below make the difference part of the type, so a
/// construction site has to say which kind it is and [resolve] is the only
/// place `tr()` is called on an error.
sealed class ErrorText {
  const ErrorText();

  /// Text for a server error, chosen the moment the failure is built.
  ///
  /// The server sends a machine-readable [code] beside its human-readable
  /// [message]. If the app owns a translation for [code] under
  /// `server.errors.*`, that translation is used; otherwise the server's own
  /// [message] is shown verbatim.
  factory ErrorText.server({required String code, required String message}) {
    final key = '$_kServerErrorPrefix.$code';
    return code.isNotEmpty && trExists(key) ? ErrorTextKey(key) : ErrorTextRaw(message);
  }

  /// The final, user-facing string.
  String resolve();
}
