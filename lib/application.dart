import 'dart:async';

import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
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

final class _ApplicationState extends State<Application> {
  late final AppRouter _appRouter;
  late final StreamSubscription<AuthenticationState>
  _authenticationSubscription;

  @override
  void initState() {
    super.initState();
    _appRouter = di<AppRouter>();
    // Any place in the app can lose the session (e.g. a 401 whose refresh
    // also failed) — react here so the redirect isn't tied to a screen.
    _authenticationSubscription = di<AuthenticationCubit>().stream.listen((
      state,
    ) {
      if (state is AuthenticationUnauthenticated) {
        _appRouter.replaceAll([const LoginRoute()]);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authenticationSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: di<AuthenticationCubit>(),
      child: MaterialApp.router(
        theme: ThemeData(extensions: const [Spacing.standard()]),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: _appRouter.config(),
      ),
    );
  }
}
