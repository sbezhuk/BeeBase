import 'package:beebase/application.dart';
import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/profile/cubit/profile_cubit/profile_cubit.dart';
import 'package:beebase/utils/app_config.dart';
import 'package:beebase/utils/di.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = Enviroment.fromDartDefine();

  await EasyLocalization.ensureInitialized();
  await AppConfig.instance.load(env);
  await initDi();
  await di<AuthenticationCubit>().restoreSession();
  // `/auth/me` (restoreSession above) no longer carries name/avatar — those
  // live on `GET /api/v1/profile` (see `Profile` entity doc). Without this,
  // AuthenticationCubit's `User` — the single source every screen reads
  // from — would only gain a name/avatar once the Profile tab happened to
  // be opened (ProfilePage.wrappedRoute's own `ProfileCubit..load()`),
  // since AutoTabsRouter builds tabs lazily. Fetch and merge it here too,
  // through the same ProfileCubit/IProfileReader path, so a cold restart
  // shows the backend's latest profile from the first frame everywhere,
  // not just after a Profile tab visit.
  if (di<AuthenticationCubit>().state is AuthenticationAuthenticated) {
    final profileCubit = di<ProfileCubit>();
    await profileCubit.load();
    await profileCubit.close();
  }
  di<SyncEngine>().start();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('uk', 'UA')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en', 'US'),
      child: const Application(),
    ),
  );
}
