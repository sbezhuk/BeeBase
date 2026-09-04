part of '../otp_input_field.dart';

final class _OtpDigitBox extends StatelessWidget {
  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.autofocus,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14);
    final normalBorder = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colors.honey.border));
    final errorBorder = normalBorder.copyWith(borderSide: BorderSide(color: colors.status.error));
    // Flutter's InputDecorator only ever renders this when the field's own
    // FocusNode actually has focus, so this is the "currently focused
    // digit" indication — no manual focus-tracking needed here.
    final focusedBorder = hasError
        ? errorBorder.copyWith(borderSide: BorderSide(color: colors.status.error, width: 1.5))
        : normalBorder.copyWith(borderSide: BorderSide(color: colors.brand.primary, width: 1.5));

    return SizedBox(
      width: 48,
      height: 56,
      child: Focus(
        onKeyEvent: (node, event) => onKeyEvent(event),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: context.textStyles.body.copyWith(fontFamily: AppFont.bold, fontSize: 20),
          cursorColor: colors.brand.primary,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: colors.surface.card,
            contentPadding: EdgeInsets.zero,
            border: hasError ? errorBorder : normalBorder,
            enabledBorder: hasError ? errorBorder : normalBorder,
            focusedBorder: focusedBorder,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
