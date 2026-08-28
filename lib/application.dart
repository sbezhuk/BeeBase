import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/router/app_router.dart';
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

final class _ApplicationState extends State<Application> with WidgetsBindingObserver {
  late final AppRouter _appRouter;
  late final StreamSubscription<AuthenticationState> _authenticationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appRouter = di<AppRouter>();
    // Any place in the app can lose the session (e.g. a 401 whose refresh
    // also failed) — react here so the redirect isn't tied to a screen.
    _authenticationSubscription = di<AuthenticationCubit>().stream.listen((state) {
      if (state is AuthenticationUnauthenticated) {
        _appRouter.replaceAll([const LoginRoute()]);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sync only depends on the foreground app being reachable at all —
    // resuming (rather than a full cold start) is when a device most often
    // regains connectivity after being backgrounded, so this is the cheap
    // "at minimum" resumption point the offline architecture needs, without
    // any platform-specific background execution.
    if (state == AppLifecycleState.resumed) {
      di<SyncEngine>().syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authenticationSubscription.cancel());
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
        routerConfig: _appRouter.config(navigatorObservers: () => [AutoRouteObserver()]),
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
