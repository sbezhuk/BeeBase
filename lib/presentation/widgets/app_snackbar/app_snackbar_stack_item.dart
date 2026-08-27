import 'dart:async';

import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_card.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_entry.dart';
import 'package:flutter/material.dart';

/// One card in [AppSnackBarStack], responsible for its own entrance/exit
/// motion and lifetime, plus how it recedes behind more recent cards.
///
/// [depth] is this card's distance from the front of the deck (0 = the
/// newest, frontmost card; 1 = one layer back, etc.) — [AppSnackBarStack]
/// recomputes it for every card whenever the active list changes, and this
/// widget smoothly animates between depths as cards are added or removed.
/// Only the frontmost card is interactive; receded cards are display-only.
final class AppSnackBarStackItem extends StatefulWidget {
  const AppSnackBarStackItem({required this.entry, required this.depth, required this.onRemoved, super.key});

  final AppSnackBarEntry entry;
  final int depth;
  final ValueChanged<Key> onRemoved;

  @override
  State<AppSnackBarStackItem> createState() => _AppSnackBarStackItemState();
}

final class _AppSnackBarStackItemState extends State<AppSnackBarStackItem> with SingleTickerProviderStateMixin {
  static const int _maxVisualDepth = 4;
  static const Duration _depthTransitionDuration = Duration(milliseconds: 280);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _expiryTimer = Timer(widget.entry.duration, _dismiss);
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _expiryTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onRemoved(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final recedeDepth = widget.depth.clamp(0, _maxVisualDepth);
    final scale = 1 - 0.06 * recedeDepth;
    final opacity = (1 - 0.18 * recedeDepth).clamp(0.35, 1.0);
    final lift = -0.1 * recedeDepth;

    return IgnorePointer(
      ignoring: widget.depth != 0,
      child: AnimatedSlide(
        offset: Offset(0, lift),
        duration: _depthTransitionDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          duration: _depthTransitionDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: _depthTransitionDuration,
            curve: Curves.easeOutCubic,
            child: Dismissible(
              key: widget.entry.id,
              direction: DismissDirection.horizontal,
              onDismissed: (_) => widget.onRemoved(widget.entry.id),
              child: FadeTransition(
                opacity: _curved,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(_curved),
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(_curved),
                    child: AppSnackBarCard(
                      message: widget.entry.message,
                      variant: widget.entry.variant,
                      actionLabel: widget.entry.actionLabel,
                      onAction: widget.entry.onAction == null
                          ? null
                          : () {
                              widget.entry.onAction!();
                              _dismiss();
                            },
                      onDismiss: _dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
