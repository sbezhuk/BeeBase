import 'package:beebase/application.dart';
import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
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
  di<SyncEngine>().start();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en', 'US'),
      child: const Application(),
    ),
  );
}
