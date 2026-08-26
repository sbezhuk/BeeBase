import 'package:flutter/foundation.dart';
import 'package:flutter_config/flutter_config.dart';

enum Enviroment {
  production('Production'),
  staging('Staging'),
  development('Development');

  const Enviroment(this.enviromentName);

  final String enviromentName;

  factory Enviroment.fromDartDefine() {
    const env = String.fromEnvironment('env', defaultValue: 'production');
    return switch (env) {
      'production' => Enviroment.production,
      'staging' => Enviroment.staging,
      'development' => Enviroment.development,
      _ => Enviroment.production,
    };
  }
}

final class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  Future<void> load(Enviroment env) async {
    final status = switch (env) {
      Enviroment.production => '🌍 Starting Production Mode',
      Enviroment.staging => '🚧 Starting Staging Mode',
      Enviroment.development => '🛠️ Starting Development Mode',
    };

    debugPrint(status);

    await FlutterConfig.loadEnvVariables();
  }

  static String get environment => FlutterConfig.get('ENVIRONMENT');

  static String get apiEndPoint => FlutterConfig.get('API_END_POINT');
}
