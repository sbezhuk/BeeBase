import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/presentation/apiary/apiary_details_page.dart';
import 'package:beebase/presentation/apiary/apiary_form_page.dart';
import 'package:beebase/presentation/apiary/apiary_list_page.dart';
import 'package:beebase/presentation/authentication/login_page.dart';
import 'package:beebase/presentation/authentication/register_page.dart';
import 'package:beebase/presentation/hive/hive_details_page.dart';
import 'package:beebase/presentation/hive/hive_form_page.dart';
import 'package:beebase/presentation/hive/hive_list_page.dart';
import 'package:beebase/presentation/home/home_page.dart';
import 'package:beebase/presentation/inspection/inspection_details_page.dart';
import 'package:beebase/presentation/inspection/inspection_form_page.dart';
import 'package:beebase/presentation/inspection/inspection_list_page.dart';
import 'package:beebase/presentation/main/main_page.dart';
import 'package:beebase/presentation/profile/profile_page.dart';
import 'package:beebase/presentation/router/guardes/authentication_guard.dart';
import 'package:flutter/widgets.dart';

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
      page: MainRoute.page,
      path: '/',
      guards: [authenticationGuard],
      initial: true,
      children: [
        AutoRoute(page: HomeRoute.page, path: 'home', initial: true),
        AutoRoute(page: ApiaryListRoute.page, path: 'apiaries'),
        AutoRoute(page: ProfileRoute.page, path: 'profile'),
      ],
    ),
    AutoRoute(page: ApiaryDetailsRoute.page, path: '/apiaries/details', guards: [authenticationGuard]),
    AutoRoute(page: ApiaryFormRoute.page, path: '/apiaries/form', guards: [authenticationGuard]),
    AutoRoute(page: HiveListRoute.page, path: '/apiaries/hives', guards: [authenticationGuard]),
    AutoRoute(page: HiveDetailsRoute.page, path: '/apiaries/hives/details', guards: [authenticationGuard]),
    AutoRoute(page: HiveFormRoute.page, path: '/apiaries/hives/form', guards: [authenticationGuard]),
    AutoRoute(page: InspectionListRoute.page, path: '/apiaries/hives/inspections', guards: [authenticationGuard]),
    AutoRoute(page: InspectionDetailsRoute.page, path: '/apiaries/hives/inspections/details', guards: [authenticationGuard]),
    AutoRoute(page: InspectionFormRoute.page, path: '/apiaries/hives/inspections/form', guards: [authenticationGuard]),
  ];
}
