// lib/env/env.dart
class Env {
  static const String mode = String.fromEnvironment(
    'MODE',
    defaultValue: 'development',
  );

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.3.22:11020',
  );

  static const bool isDev = mode == 'development';
  static const bool isProd = mode == 'production';

  /// 给 UI 用的 label（关键）
  static const String label = isProd ? 'PROD' : 'DEV';
}
