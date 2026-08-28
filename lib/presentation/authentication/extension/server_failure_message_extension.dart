import 'package:beebase/core/error/error_text.dart';

extension AuthFieldErrorCode on String {
  /// Localized display copy for a single `fields` entry's code (e.g.
  /// `email_required`). Falls back to the code itself so an unmapped code
  /// never disappears silently.
  String get authFieldErrorMessage => ErrorText.server(code: this, message: this).resolve();
}
