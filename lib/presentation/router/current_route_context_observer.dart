import 'package:flutter/widgets.dart';

/// Tracks the [BuildContext] of whichever route currently sits on top of the
/// navigation stack, so an app-wide listener (e.g. the connectivity
/// notifier in `Application`) can call [AppSnackBar.show] without depending
/// on a specific screen's context.
///
/// [ModalRoute.subtreeContext] is used rather than a route's own
/// `navigator.context` because only the former is mounted inside the
/// [Overlay] that `AppSnackBar.show`'s `rootOverlay: true` resolves to —
/// the [Navigator]'s own context sits above the [Overlay] it builds, not
/// inside it. It's read one frame after push/pop since the route's subtree
/// isn't built yet at the point the observer callback fires.
final class CurrentRouteContextObserver extends NavigatorObserver {
  BuildContext? _context;

  BuildContext? get currentContext => (_context?.mounted ?? false) ? _context : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _capture(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _capture(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _capture(newRoute);

  void _capture(Route<dynamic>? route) {
    if (route is! ModalRoute) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _context = route.subtreeContext);
  }
}
