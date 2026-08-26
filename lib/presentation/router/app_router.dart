import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/authentication/login_page.dart';
import 'package:beebase/presentation/authentication/register_page.dart';
import 'package:beebase/presentation/home/home_page.dart';
import 'package:beebase/presentation/router/guardes/authentication_guard.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
final class AppRouter extends RootStackRouter {
  AppRouter({required this.authenticationGuard});

  final AuthenticationGuard authenticationGuard;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: LoginRoute.page, path: '/login'),
    AutoRoute(page: RegisterRoute.page, path: '/register'),
    AutoRoute(
      page: HomeRoute.page,
      path: '/',
      guards: [authenticationGuard],
      initial: true,
    ),
  ];
}
