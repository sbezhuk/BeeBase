import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/presentation/router/app_router.dart';

/// Gates authenticated routes on the presence of a locally stored access
/// token. Deliberately does not perform a network round trip here — the
/// token may be stale/expired, but [AuthenticationInterceptor] will
/// transparently refresh it on the first authenticated request, and the
/// root [AuthenticationCubit] listener redirects back to login if that
/// refresh ultimately fails.
final class AuthenticationGuard extends AutoRouteGuard {
  AuthenticationGuard({required this.tokenStorage});

  final TokenStorage tokenStorage;

  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    final hasSession = await tokenStorage.hasAccessToken();
    if (hasSession) {
      resolver.next(true);
    } else {
      resolver.next(false);
      router.push(const LoginRoute());
    }
  }
}
