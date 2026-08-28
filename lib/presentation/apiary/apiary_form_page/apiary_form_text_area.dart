part of '../apiary_form_page.dart';

/// Multi-line counterpart to [_ApiaryFormField] — same label-above-field and
/// focus-glow language. No leading icon here: Flutter centers a decoration's
/// `prefixIcon` across the *whole* input height once it has multiple lines,
/// which reads oddly for a textarea, so this field stays icon-free rather
/// than fighting that layout.
final class _ApiaryFormTextArea extends StatefulWidget {
  const _ApiaryFormTextArea({required this.label, required this.controller, required this.hintText});

  final String label;
  final TextEditingController controller;
  final String hintText;

  @override
  State<_ApiaryFormTextArea> createState() => _ApiaryFormTextAreaState();
}

final class _ApiaryFormTextAreaState extends State<_ApiaryFormTextArea> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.textStyles.label),
        SizedBox(height: context.spacing.xs),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: _isFocused
                ? [BoxShadow(color: colors.primary.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))]
                : const [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: 4,
            style: context.textStyles.body,
            cursorColor: colors.primary,
            decoration: InputDecoration(
              hintText: widget.hintText,
              filled: true,
              fillColor: colors.surface,
              contentPadding: EdgeInsets.all(context.spacing.md),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: colors.honeyBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: colors.honeyBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
