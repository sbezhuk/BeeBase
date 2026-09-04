import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'otp_input_field/otp_digit_box.dart';

/// A 6-box one-time-code input, shared by every OTP/TOTP verification screen
/// in the app (login 2FA, TOTP setup, forgot-password, change-password).
///
/// Reads and writes its value through [controller] as one concatenated
/// string, and takes a [validator], exactly like [AppTextField] — so it
/// drops into the same `Form` + `validator` + server-error pattern every
/// other field in the app already uses; callers keep validating and reading
/// the code through the same controller they pass in.
final class OtpInputField extends StatefulWidget {
  const OtpInputField({
    required this.controller,
    required this.label,
    this.length = 6,
    this.validator,
    this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final int length;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onChanged;
  final bool autofocus;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

final class _OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _digitControllers = List.generate(
    widget.length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(widget.length, (_) => FocusNode());

  // Set while this widget is the one writing widget.controller, so the
  // listener below doesn't re-derive the boxes from the value it just wrote.
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _applyExternalValue(widget.controller.text);
    widget.controller.addListener(_handleExternalChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleExternalChanged);
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _value => _digitControllers.map((controller) => controller.text).join();

  void _handleExternalChanged() {
    if (_isPublishing || widget.controller.text == _value) return;
    setState(() => _applyExternalValue(widget.controller.text));
  }

  void _applyExternalValue(String value) {
    for (var i = 0; i < widget.length; i++) {
      _digitControllers[i].text = i < value.length ? value[i] : '';
    }
  }

  void _publish(FormFieldState<String> field) {
    _isPublishing = true;
    widget.controller.text = _value;
    _isPublishing = false;
    field.didChange(_value);
    widget.onChanged?.call();
  }

  void _handleInput(int index, String rawValue, FormFieldState<String> field) {
    final digits = rawValue.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _distributePaste(digits, startIndex: index);
    } else {
      _digitControllers[index].text = digits;
      if (digits.isNotEmpty && index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }
    _publish(field);
  }

  // A paste lands its full clipboard text into whichever box triggered it;
  // spread the digits from there across the remaining boxes and focus the
  // next empty one (or the last box, once the code is complete).
  void _distributePaste(String digits, {required int startIndex}) {
    var digitIndex = 0;
    for (var i = startIndex; i < widget.length && digitIndex < digits.length; i++, digitIndex++) {
      _digitControllers[i].text = digits[digitIndex];
    }
    final nextEmptyIndex = _digitControllers.indexWhere((controller) => controller.text.isEmpty);
    _focusNodes[nextEmptyIndex == -1 ? widget.length - 1 : nextEmptyIndex].requestFocus();
  }

  // Backspace on an already-empty box has nothing to delete locally, so it
  // steps back and clears the previous box instead — TextField's own
  // onChanged never fires for that case since no text in *this* box changes.
  KeyEventResult _handleKeyEvent(int index, FormFieldState<String> field, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_digitControllers[index].text.isEmpty && index > 0) {
      _digitControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _publish(field);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return FormField<String>(
      initialValue: _value,
      validator: widget.validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: context.textStyles.label),
            SizedBox(height: spacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.length; i++)
                  _OtpDigitBox(
                    controller: _digitControllers[i],
                    focusNode: _focusNodes[i],
                    hasError: field.hasError,
                    autofocus: widget.autofocus && i == 0,
                    onChanged: (value) => _handleInput(i, value, field),
                    onKeyEvent: (event) => _handleKeyEvent(i, field, event),
                  ),
              ],
            ),
            if (field.hasError) ...[
              SizedBox(height: spacing.xs),
              Padding(
                padding: EdgeInsets.only(left: spacing.xs / 2),
                child: Text(field.errorText!, style: context.textStyles.error),
              ),
            ],
          ],
        );
      },
    );
  }
}
