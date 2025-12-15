import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';

Future<void> bootstrap(
  FutureOr<Widget> Function() builder, {
  required AppConfig config,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: config.envFile);
  AppLogger.init(isProd: config.isProd);

  runZonedGuarded(
    () async {
      final app = await builder();
      runApp(app);
    },
    (error, stack) {
      AppLogger.e('Uncaught', error: error, stackTrace: stack);
      // TODO: 可上报到 Sentry/Firebase
    },
  );
}
