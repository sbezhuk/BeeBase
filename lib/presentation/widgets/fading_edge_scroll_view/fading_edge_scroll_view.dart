import 'package:beebase/presentation/widgets/fading_edge_scroll_view/edge_fade_options.dart';
import 'package:flutter/material.dart';

/// Fades scroll content near whichever edge still has more to reveal,
/// easing in as the user scrolls away from that edge rather than sitting
/// on screen as a static overlay.
final class FadingEdgeScrollView extends StatefulWidget {
  const FadingEdgeScrollView({
    required this.child,
    this.topFadeHeight = 20,
    this.bottomFadeHeight = 20,
    this.topFadeOffset = 24,
    this.bottomFadeOffset = 24,
    this.enableTopFade = true,
    this.enableBottomFade = true,
    this.disallowGlow = true,
    this.maxFadeOpacity = 0.35,
    super.key,
  });

  final Widget child;
  final double topFadeHeight;
  final double bottomFadeHeight;
  final double topFadeOffset;
  final double bottomFadeOffset;
  final bool enableTopFade;
  final bool enableBottomFade;
  final bool disallowGlow;

  /// Caps how far the fade can go: at full ease it only dims content to
  /// `1 - maxFadeOpacity` opacity instead of erasing it, so whatever sits
  /// behind this widget in a [Stack] never shows through as a hard cut.
  final double maxFadeOpacity;

  @override
  State<FadingEdgeScrollView> createState() => _FadingEdgeScrollViewState();
}

final class _FadingEdgeScrollViewState extends State<FadingEdgeScrollView> {
  late final ValueNotifier<EdgeFadeOptions> _edgeFadeOptions = ValueNotifier(
    EdgeFadeOptions(topFadeHeight: widget.topFadeHeight, bottomFadeHeight: widget.bottomFadeHeight),
  );

  @override
  void dispose() {
    _edgeFadeOptions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _handleNotification,
      child: ValueListenableBuilder<EdgeFadeOptions>(
        valueListenable: _edgeFadeOptions,
        builder: (context, options, child) {
          return ShaderMask(
            blendMode: BlendMode.dstOut,
            shaderCallback: (bounds) => _buildShader(bounds, options),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  bool _handleNotification(Notification notification) {
    if (notification is ScrollNotification) {
      _updateFadeValues(notification.metrics.extentBefore, notification.metrics.extentAfter);
    }
    if (widget.disallowGlow && notification is OverscrollIndicatorNotification) {
      notification.disallowIndicator();
    }
    // Must not swallow the notification — ancestors like RefreshIndicator
    // need it to keep bubbling up to detect pull-to-refresh gestures.
    return false;
  }

  void _updateFadeValues(double extentBefore, double extentAfter) {
    var options = _edgeFadeOptions.value;
    if (widget.enableTopFade) {
      final topFadeValue = extentBefore > widget.topFadeOffset ? 1.0 : extentBefore / widget.topFadeOffset;
      options = options.copyWith(topFadeValue: topFadeValue);
    }
    if (widget.enableBottomFade) {
      final bottomFadeValue = extentAfter > widget.bottomFadeOffset ? 1.0 : extentAfter / widget.bottomFadeOffset;
      options = options.copyWith(bottomFadeValue: bottomFadeValue);
    }
    _edgeFadeOptions.value = options;
  }

  Shader _buildShader(Rect bounds, EdgeFadeOptions options) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: options.topFadeValue * widget.maxFadeOpacity),
        Colors.transparent,
        Colors.transparent,
        Colors.white.withValues(alpha: options.bottomFadeValue * widget.maxFadeOpacity),
      ],
      stops: [0, options.topFadeHeight / bounds.height, 1 - (options.bottomFadeHeight / bounds.height), 1],
    ).createShader(bounds);
  }
}
