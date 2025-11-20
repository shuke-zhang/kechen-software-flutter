import 'package:logger/logger.dart';

class AppLogger {
  static late Logger _logger;

  static void init({required bool isProd}) {
    _logger = Logger(
      level: isProd ? Level.info : Level.debug,
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 5,
        printTime: true,
      ),
    );
  }

  static void d(dynamic message) => _logger.d(message);
  static void i(dynamic message) => _logger.i(message);
  static void w(dynamic message) => _logger.w(message);
  static void e(dynamic message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
