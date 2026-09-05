import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/router/current_route_context_observer.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/themes/spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

final class _ApplicationState extends State<Application> {
  late final AppRouter _appRouter;
  late final StreamSubscription<AuthenticationState> _authenticationSubscription;
  late final StreamSubscription<bool> _connectivitySubscription;
  final _routeContextObserver = CurrentRouteContextObserver();

  @override
  void initState() {
    super.initState();
    _appRouter = di<AppRouter>();
    // Any place in the app can lose the session (e.g. a 401 whose refresh
    // also failed) — react here so the redirect isn't tied to a screen.
    _authenticationSubscription = di<AuthenticationCubit>().stream.listen((state) {
      if (state is AuthenticationUnauthenticated) {
        _appRouter.replaceAll([const LoginRoute()]);
      }
    });
    // `INetworkInfo.onConnectivityChanged` only fires on an actual
    // online/offline flip (see `NetworkInfo._notifyIfChanged`), so this
    // never repeats a toast while the state is unchanged. It's reacted to
    // here rather than on a specific screen so it fires no matter what the
    // user is currently looking at.
    _connectivitySubscription = di<INetworkInfo>().onConnectivityChanged.listen((isOnline) {
      final routeContext = _routeContextObserver.currentContext;
      if (routeContext == null || !routeContext.mounted) return;
      AppSnackBar.show(
        routeContext,
        message: isOnline ? 'core.connectivity.online'.tr() : 'core.connectivity.offline'.tr(),
        variant: isOnline ? AppSnackBarVariant.success : AppSnackBarVariant.warning,
      );
    });
  }

  @override
  void dispose() {
    unawaited(_authenticationSubscription.cancel());
    unawaited(_connectivitySubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: di<AuthenticationCubit>(),
      child: MaterialApp.router(
        theme: _buildTheme(const AppColor.light(), Brightness.light),
        darkTheme: _buildTheme(const AppColor.dark(), Brightness.dark),
        themeMode: ThemeMode.system,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: _appRouter.config(navigatorObservers: () => [AutoRouteObserver(), _routeContextObserver]),
      ),
    );
  }
}

ThemeData _buildTheme(AppColor colors, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    fontFamily: AppFont.regular,
    scaffoldBackgroundColor: colors.surface.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.brand.primary,
      brightness: brightness,
      primary: colors.brand.primary,
      error: colors.status.error,
      surface: colors.surface.card,
    ),
    extensions: [const Spacing.standard(), colors, AppTextStyles.fromColors(colors)],
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.brand.primary,
      selectionColor: colors.brand.primary.withValues(alpha: 0.3),
      selectionHandleColor: colors.brand.primary,
    ),
  );
}
