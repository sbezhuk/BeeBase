import 'package:flutter/foundation.dart';
import 'package:flutter_config/flutter_config.dart';

enum Enviroment {
  prod('Production');

  const Enviroment(this.enviromentName);

  final String enviromentName;

  factory Enviroment.fromDartDefine() {
    const env = String.fromEnvironment('env', defaultValue: 'prod');
    return switch (env) {
      'prod' => Enviroment.prod,
      _ => Enviroment.prod,
    };
  }
}

final class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  Future<void> load(Enviroment env) async {
    final status = switch (env) {
      Enviroment.prod => '🌍 Starting Production Mode',
    };

    debugPrint(status);

    await FlutterConfig.loadEnvVariables();
  }

  static String get environment => FlutterConfig.get('ENVIRONMENT');
}
