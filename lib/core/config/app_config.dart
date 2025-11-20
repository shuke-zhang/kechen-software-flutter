enum AppEnv { dev, prod }

class AppConfig {
  final AppEnv env;
  const AppConfig({required this.env});

  bool get isProd => env == AppEnv.prod;
  String get label => isProd ? 'PROD' : 'DEV';
  String get envFile => isProd ? '.env.prod' : '.env';
}
